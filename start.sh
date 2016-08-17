#!/bin/sh
dnsmasq -k &
cloud-config-server &
nohup registry serve /etc/docker/registry/config.yml &
sleep 2
docker load < /opt/hyperkube-adm64:v1.2.4.tar
docker load < /opt/pause:2.0.tar
docker tag hyperkube-adm64:v1.2.4 localhost:5000/hyperkube-adm64:v1.2.4
docker tag pause:2.0 localhost:5000/pause:2.0
docker push localhost:5000/hyperkube-adm64:v1.2.4
docker push localhost:5000/pause:2.0

while :
  do
  sleep 10
  done
