#!/bin/sh
# FIXME: DEFAULT_IPV4 may not accessible by clients?
DEFAULT_IPV4=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
sed -i 's/<HTTP_ADDR>/'"$DEFAULT_IPV4"':8088/g' /go/static/install.sh
dnsmasq -k --log-facility=- --conf-file=/etc/dnsmasq.conf &
cloud-config-server -addr ":8088" &
registry serve /etc/docker/registry/config.yml &
sleep 2
docker load < /opt/hyperkube-amd64_v1.2.0.tar
docker load < /opt/pause_2.0.tar
docker tag typhoon1986/hyperkube-amd64:v1.2.0 $DEFAULT_IPV4:5000/hyperkube-amd64:v1.2.0
docker tag typhoon1986/pause:2.0 $DEFAULT_IPV4:5000/pause:2.0
docker push $DEFAULT_IPV4:5000/hyperkube-amd64:v1.2.0
docker push $DEFAULT_IPV4:5000/pause:2.0
wait
