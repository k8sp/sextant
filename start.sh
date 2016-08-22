#!/bin/sh
# FIXME: DEFAULT_IPV4 is the last ip
DEFAULT_IPV4=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
sed -i 's/<HTTP_ADDR>/'"$DEFAULT_IPV4"':8081/g' /bsroot/html/static/cloud-configs/install.sh
# start dnsmasq
dnsmasq --log-facility=- -q --conf-file=/bsroot/config/dnsmasq.conf
# start cloud-config-server
cloud-config-server -addr ":8081" \
  -dir /bsroot/html/static \
  -cc-template-file /bsroot/config/cloud-config.template \
  -cc-template-url "" \
  -cluster-desc-file /bsroot/config/cluster-desc.yml \
  -cluster-desc-url "" \
  -ca-crt /bsroot/tls/ca.pem \
  -ca-key /bsroot/tls/ca-key.pem &
# start registry
registry serve /bsroot/config/registry.yml &
sleep 2
# push k8s images to registry from bsroot
docker load < /bsroot/hyperkube-amd64_v1.2.0.tar
docker load < /bsroot/pause_2.0.tar
docker tag typhoon1986/hyperkube-amd64:v1.2.0 $DEFAULT_IPV4:5000/hyperkube-amd64:v1.2.0
docker tag typhoon1986/pause:2.0 $DEFAULT_IPV4:5000/pause:2.0
docker push $DEFAULT_IPV4:5000/hyperkube-amd64:v1.2.0
docker push $DEFAULT_IPV4:5000/pause:2.0
wait
