#!/bin/bash
# default to install coreos on /dev/sda
if [ -z {$DISK_DEV} ] ; then
  DISK_DEV=/dev/sda
fi
mac_addr=`ifconfig | grep -A2 'broadcast' | grep -o '..:..:..:..:..:..' | tail -n1`
wget http://<HTTP_ADDR>/cloud-configs/${mac_addr}.yml
sudo coreos-install -d {$DISK_DEV} -c ${mac_addr}.yml -b http://<HTTP_ADDR>/static
sudo reboot
