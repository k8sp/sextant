#!/bin/bash
# FIXME: default to install coreos on /dev/sda
mac_addr=`ifconfig | grep -A2 'broadcast' | grep -o '..:..:..:..:..:..' | tail -n1`
wget -O ${mac_addr}.yml http://<HTTP_ADDR>/cloud-config/${mac_addr}
sudo coreos-install -d /dev/sda -c ${mac_addr}.yml -b http://<HTTP_ADDR>/static -V current
sudo reboot
