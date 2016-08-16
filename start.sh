#!/bin/sh
dnsmasq -k &
cloud-config-server &
registry serve /etc/docker/registry/config.yml
