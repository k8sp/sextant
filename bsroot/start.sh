#!/bin/ash

# The trailing & runs cloud-config-server in background.
/bsroot/cloud-config-server \
    --cluster-desc-url="" \
    --cluster-desc-file=/bsroot/cluster-desc.yml \
    --cc-template-url="" \
    --cc-template-file=/bsroot/cloud-config.template \
    --ca-crt=/bsroot/ca.crt \
    --ca-key=/bsroot/ca.key \
    --dir=/bsroot/www \
    --addr=:8080 & 

# Without an explicity -k flag, dnsmasq runs in background by default.
/usr/sbin/dnsmasq -C /bsroot/dnsmasq.conf 

# TODO: to make registry run in background, need a trailing #.
/go/bin/registry serve /bsroot/registry.yml
