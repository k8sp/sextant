#!/bin/bash
#Obtain devices
devices=$(lsblk -l |awk '$6=="disk"{print $1}')
# Zap all devices
# NOTICE: dd zero to device mbr will not affect parted printed table,
#         so use parted to remove the part tables
for d in $devices
do
  for v_partition in $(parted -s /dev/${d} print|awk '/^ / {print $1}')
  do
     parted -s /dev/${d} rm ${v_partition}
  done
done

# FIXME: default to install coreos on /dev/sda
mac_addr=`ifconfig | grep -A2 'broadcast' | grep -o '..:..:..:..:..:..' | tail -n1`
wget -O ${mac_addr}.yml http://<HTTP_ADDR>/cloud-config/${mac_addr}
sudo coreos-install -d /dev/sda -c ${mac_addr}.yml -b http://<HTTP_ADDR>/static -V current
sudo reboot
