#!/usr/bin/env bash

if [ ZSP_AND_START_OSD = 1  ]; then
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
  # make sure to wipe out the GPT infomation, let ceph uses gdisk to init
  dd if=/dev/zero of=/dev/${d} bs=512 count=2
  parted -s /dev/${d} mklabel gpt
done
fi


# FIXME: default to install coreos on /dev/sda
default_iface=$(awk '$2 == 00000000 { print $1  }' /proc/net/route | uniq)

printf "Default interface: ${default_iface}\n"
default_iface=$(echo ${default_iface} | awk '{ print \$1 }')

mac_addr=$(ip addr show dev ${default_iface} | awk '$1 ~ /^link\// { print $2 }')
printf "Interface: ${default_iface} MAC address: ${mac_addr}\n"

wget -O ${mac_addr}.yml http://BS_IP/cloud-config/${mac_addr}
sudo coreos-install -d /dev/sda -c ${mac_addr}.yml -b http://BS_IP/static -V current && sudo reboot

