#!/bin/bash
#Obtain devices
devices=$(lsblk -l |awk '$6=="disk"{print $1}')
# Zap all devices
for d in $devices
do
  device="/dev/$d"
  dd if=/dev/zero of=$device bs=512 count=1 conv=notrunc
done

# FIXME: default to install coreos on /dev/sda
mac_addr=`ifconfig | grep -A2 'broadcast' | grep -o '..:..:..:..:..:..' | tail -n1`
wget -O ${mac_addr}.yml http://<HTTP_ADDR>/cloud-config/${mac_addr}
sudo coreos-install -d /dev/sda -c ${mac_addr}.yml -b http://<HTTP_ADDR>/static -V current
sudo reboot
