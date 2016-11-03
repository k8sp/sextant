#!/bin/sh

# start dnsmasq
dnsmasq --log-facility=- -q --conf-file=/bsroot/config/dnsmasq.conf \
  --dhcp-leasefile=/bsroot/dnsmasq/dnsmasq.leases

# start cloud-config-server
/cloud-config-server -addr ":80" \
  -dir /bsroot/html/static \
  -cc-template-file /bsroot/config/cloud-config.template \
  -cc-template-url "" \
  -cluster-desc-file /bsroot/config/cluster-desc.yml \
  -cluster-desc-url "" \
  -ca-crt /bsroot/tls/ca.pem \
  -ca-key /bsroot/tls/ca-key.pem &

# start registry
/registry serve /bsroot/config/registry.yml &
sleep 2

wait
