#!/bin/bash

#生成ssh key
rm -rf /root/.ssh/
/usr/bin/ssh-keygen -t rsa -f /root/.ssh/id_rsa -P ''
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

#设置bootstrapper免密码登陆其他虚拟机
ssh_key=`cat /root/.ssh/authorized_keys` 
sed -i -e 's#<SSH_KEY>#'"$ssh_key"'#' /bsroot/config/cluster-desc.yml

#设置docker registry tls ca证书
mkdir -p /etc/docker/certs.d/bootstrapper:5000
cp  /bsroot/tls/ca.pem /etc/docker/certs.d/bootstrapper:5000/ca.crt
systemctl daemon-reload
systemctl restart docker

#修复无法找到pxe　server的异常
sed -i '/interface=eth0/,/bind-interfaces/d' /bsroot/config/dnsmasq.conf

#启动dnsmasq,cloudconfig server,docker registry
docker load < /bsroot/bootstrapper.tar
docker run -d --net=host \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /bsroot:/bsroot \
  bootstrapper
