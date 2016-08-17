#!/bin/sh
dnsmasq -k --log-facility=- --conf-file=/etc/dnsmasq.conf &
cloud-config-server &
registry serve /etc/docker/registry/config.yml &
wait
