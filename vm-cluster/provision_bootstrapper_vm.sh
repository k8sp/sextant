#!/bin/bash

#生成ssh key
rm -rf /root/.ssh/
/usr/bin/ssh-keygen -t rsa -f /root/.ssh/id_rsa -P ''
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

#设置bootstrapper免密码登陆其他虚拟机
ssh_key=`cat /root/.ssh/authorized_keys` 
sed -i -e 's#<SSH_KEY>#'"$ssh_key"'#' /bsroot/config/cluster-desc.yml

#修复无法找到pxe　server的异常
sed -i '/interface=eth0/,/bind-interfaces/d' /bsroot/config/dnsmasq.conf
cd /bsroot
./start_bootstrapper_container.sh /bsroot
