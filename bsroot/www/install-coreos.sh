#!/bin/sh
mac_addr=`ip a | grep -A2 BROADCAST | grep -o 'link/ether ..:..:..:..:..:.. ' | grep -o '..:..:..:..:..:..'`
wget http://192.168.50.4:8080/cloud-config/${mac_addr}.yml
sudo coreos-install -d /dev/sda -c ${mac_addr}.yml -C stable -V 1068.9.0 -b http://192.168.50.4:8080/static
sudo reboot
