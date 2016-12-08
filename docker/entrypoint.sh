#!/bin/sh

# start dnsmasq
mkdir -p /bsroot/dnsmasq
dnsmasq --log-facility=- -q --conf-file=/bsroot/config/dnsmasq.conf \
  --dhcp-leasefile=/bsroot/dnsmasq/dnsmasq.leases

# start cloud-config-server
/go/bin/cloud-config-server -addr ":80" \
  -dir /bsroot/html/static \
  -cloud-config-dir /bsroot/config/templatefiles \
  -cluster-desc /bsroot/config/cluster-desc.yml \
  -ca-crt /bsroot/tls/ca.pem \
  -ca-key /bsroot/tls/ca-key.pem &

# start registry
/go/bin/registry serve /bsroot/config/registry.yml &
sleep 2

wait
