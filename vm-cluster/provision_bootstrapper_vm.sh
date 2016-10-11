#!/bin/bash

# Copy VM keys out from /bsroot/vm-keys.
mkdir -p /root/.ssh
rm -rf /root/.ssh/*
cp /bsroot/vm-keys/* /root/.ssh
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

#修复无法找到pxe　server的异常
sed -i '/interface=eth0/,/bind-interfaces/d' /bsroot/config/dnsmasq.conf

cd /bsroot
./start_bootstrapper_container.sh /bsroot
