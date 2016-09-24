#!/bin/sh
# FIXME: DEFAULT_IPV4 is the last ip
DEFAULT_IPV4=`grep "bootstrapper:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g'`
BOOTATRAPPER_DOMAIN=`grep "dockerdomain:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/"//g' | sed 's/ //g'`
MASTER_HOSTNAME=`grep "kube_master: y" /bsroot/config/cluster-desc.yml -B 5 |grep "mac" | awk '{print $3}' | sed 's/"//g'`
# start dnsmasq
dnsmasq --log-facility=- -q --conf-file=/bsroot/config/dnsmasq.conf
# run addons
addons -cluster-desc-file /bsroot/config/cluster-desc.yml \
  -template-file /bsroot/config/ingress.template \
  -config-file /bsroot/html/static/ingress.yaml &

addons -cluster-desc-file /bsroot/config/cluster-desc.yml \
  -template-file /bsroot/config/skydns.template \
  -config-file /bsroot/html/static/skydns.yaml &

# start cloud-config-server
cloud-config-server -addr ":80" \
  -dir /bsroot/html/static \
  -cc-template-file /bsroot/config/cloud-config.template \
  -cc-template-url "" \
  -cluster-desc-file /bsroot/config/cluster-desc.yml \
  -cluster-desc-url "" \
  -ca-crt /bsroot/tls/ca.pem \
  -ca-key /bsroot/tls/ca-key.pem \
  -ingress-template-file /bsroot/config/ingress.template \
  -skydns-template-file /bsroot/config/skydns.template &
# start registry
registry serve /bsroot/config/registry.yml &
sleep 2
wait
