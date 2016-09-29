#!/bin/sh

dnsmasq \
    --log-facility=- \
    -q \
    --conf-file=/bsroot/config/dnsmasq.conf

/go/bin/addons \
    -cluster-desc-file /bsroot/config/cluster-desc.yml \
    -template-file /bsroot/config/ingress.template \
    -config-file /bsroot/html/static/ingress.yaml &

/go/bin/addons \
    -cluster-desc-file /bsroot/config/cluster-desc.yml \
    -template-file /bsroot/config/skydns.template \
    -config-file /bsroot/html/static/skydns.yaml &

/go/bin/cloud-config-server \
    -addr ":80" \
    -dir /bsroot/html/static \
    -cc-template-file /bsroot/config/cloud-config.template \
    -cc-template-url "" \
    -cluster-desc-file /bsroot/config/cluster-desc.yml \
    -cluster-desc-url "" \
    -ca-crt /bsroot/tls/ca.pem \
    -ca-key /bsroot/tls/ca-key.pem &

/go/bin/registry serve /bsroot/config/registry.yml &
sleep 2
wait
