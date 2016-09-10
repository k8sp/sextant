#!/bin/sh
# FIXME: DEFAULT_IPV4 is the last ip
DEFAULT_IPV4=`grep "bootstrapper:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g'`
BOOTATRAPPER_DOMAIN=`grep "dockerdomain:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/"//g' | sed 's/ //g'`

# update install.sh domain
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
docker load < /bsroot/flannel_0.5.5.tar
docker tag typhoon1986/hyperkube-amd64:v1.2.0 $BOOTATRAPPER_DOMAIN:5000/hyperkube-amd64:v1.2.0
docker tag typhoon1986/pause:2.0 $BOOTATRAPPER_DOMAIN:5000/pause:2.0
docker tag typhoon1986/flannel:0.5.5 $BOOTATRAPPER_DOMAIN:5000/flannel:0.5.5
docker push $BOOTATRAPPER_DOMAIN:5000/hyperkube-amd64:v1.2.0
docker push $BOOTATRAPPER_DOMAIN:5000/pause:2.0
docker push $BOOTATRAPPER_DOMAIN:5000/flannel:0.5.5
# push ceph images to registry
docker load < /bsroot/ceph_daemon.tar
docker tag typhoon1986/ceph-daemon:tag-build-master-jewel-ubuntu-14.04-fix370 $BOOTATRAPPER_DOMAIN:5000/ceph/daemon:tag-build-master-jewel-ubuntu-14.04-fix370
docker push $BOOTATRAPPER_DOMAIN:5000/ceph/daemon:tag-build-master-jewel-ubuntu-14.04-fix370
wait
