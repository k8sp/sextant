#!/bin/sh
# FIXME: DEFAULT_IPV4 is the last ip
DEFAULT_IPV4=`grep "bootstrapper:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g'`
BOOTATRAPPER_DOMAIN=`grep "dockerdomain:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/"//g' | sed 's/ //g'`

# update install.sh domain
sed -i 's/<HTTP_ADDR>/'"$DEFAULT_IPV4"'/g' /bsroot/html/static/cloud-configs/install.sh
# start dnsmasq
dnsmasq --log-facility=- -q --conf-file=/bsroot/config/dnsmasq.conf
# start cloud-config-server
cloud-config-server -addr ":80" \
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
hyperkube_version=`grep "hyperkube_version:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`
pause_version=`grep "pause_version:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`
flannel_version=`grep "flannel_version:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`

docker load < /bsroot/bootstrapper.tar
docker run -d --net=host \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /bsroot:/bsroot \
  bootstrapper

docker load < /bsroot/hyperkube-amd64.tar
docker load < /bsroot/pause.tar
docker load < /bsroot/flannel.tar
docker tag typhoon1986/hyperkube-amd64:$hyperkube_version $BOOTATRAPPER_DOMAIN:5000/hyperkube-amd64:$hyperkube_version
docker tag typhoon1986/pause-amd64:$pause_version $BOOTATRAPPER_DOMAIN:5000/pause-amd64:$pause_version
docker tag typhoon1986/flannel:$flannel_version $BOOTATRAPPER_DOMAIN:5000/flannel:$flannel_version
docker push $BOOTATRAPPER_DOMAIN:5000/hyperkube-amd64:$hyperkube_version
docker push $BOOTATRAPPER_DOMAIN:5000/pause-amd64:$pause_version
docker push $BOOTATRAPPER_DOMAIN:5000/flannel:$flannel_version
wait
