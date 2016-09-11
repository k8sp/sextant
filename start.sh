#!/bin/sh
# FIXME: DEFAULT_IPV4 is the last ip
DEFAULT_IPV4=`grep "bootstrapper:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g'`
BOOTATRAPPER_DOMAIN=`grep "dockerdomain:" /bsroot/config/cluster-desc.yml | awk '{print $2}' | sed 's/"//g' | sed 's/ //g'`
MASTER_HOSTNAME=`grep "kube_master: y" /bsroot/config/cluster-desc.yml -B 5 |grep "mac" | awk '{print $3}' | sed 's/"//g'`
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
  -ca-key /bsroot/tls/ca-key.pem \
  -ingress-template-file /bsroot/config/ingress.template \
  -skydns-template-file /bsroot/config/skydns.template &
# start registry
registry serve /bsroot/config/registry.yml &
sleep 2
# push k8s images to registry from bsroot
docker load < /bsroot/hyperkube-amd64_v1.2.0.tar
docker load < /bsroot/pause_2.0.tar
docker load < /bsroot/flannel_0.5.5.tar
docker load < /bsroot/nginx-ingress-controller_0.8.3.tar
docker load < /bsroot/kube2sky_1.14.tar
docker load < /bsroot/exechealthz_1.0.tar
docker load < /bsroot/skydns_latest.tar
docker tag typhoon1986/hyperkube-amd64:v1.2.0 $BOOTATRAPPER_DOMAIN:5000/hyperkube-amd64:v1.2.0
docker tag typhoon1986/pause:2.0 $BOOTATRAPPER_DOMAIN:5000/pause:2.0
docker tag typhoon1986/flannel:0.5.5 $BOOTATRAPPER_DOMAIN:5000/flannel:0.5.5
docker tag yancey1989/nginx-ingress-controller:0.8.3 $BOOTATRAPPER_DOMAIN:5000/nginx-ingress-controller:0.8.3
docker tag yancey1989/kube2sky:1.14 $BOOTATRAPPER_DOMAIN:5000/kube2sky:1.14
docker tag typhoon1986/exechealthz:1.0 $BOOTATRAPPER_DOMAIN/exechealthz:1.0
docker tag typhoon1986/skydns:latest $BOOTATRAPPER_DOMAIN/skydns:latest
docker push $BOOTATRAPPER_DOMAIN:5000/hyperkube-amd64:v1.2.0
docker push $BOOTATRAPPER_DOMAIN:5000/pause:2.0
docker push $BOOTATRAPPER_DOMAIN:5000/flannel:0.5.5
docker push $BOOTATRAPPER_DOMAIN:5000/nginx-ingress-controller:0.8.3
docker push $BOOTATRAPPER_DOMAIN:5000/kube2sky:1.14
docker push $BOOTATRAPPER_DOMAIN/exechealthz:1.0
docker push $BOOTATRAPPER_DOMAIN/skydns:latest
# config kubectl
kubectl set-cluster config set-cluster k8sp --server http://$MASTER_HOSTNAME:8080
kubectl config set-context k8sp --cluster=k8sp
kubectl config use-context k8sp
kubectl create -f /bsroot/html/static/ingress.yaml
kubectl create -f /bsroot/html/static/skydns.yaml
wait
