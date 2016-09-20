#!/bin/bash
# FIXME: default to install coreos on /dev/sda
default_iface=$(awk '$2 == 00000000 { print $1  }' /proc/net/route)
mac_addr=`ip addr show dev "$default_iface" | awk '$1 ~ /^link\// { print $2 }'`
wget --quiet -O ${mac_addr}.yml http://<HTTP_ADDR>/cloud-config/${mac_addr}
sudo coreos-install -d /dev/sda -c ${mac_addr}.yml -b http://<HTTP_ADDR>/static -V current
sudo reboot
