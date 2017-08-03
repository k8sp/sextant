#!/bin/bash

# start_bootstrapper_container.sh load docker image from bsroot and
# then push them to registry
if [[ "$#" -gt 1 ]]; then
    echo "Usage: start_bootstrapper_container.sh [bsroot-path]"
    exit 1
elif [[ "$#" -ne 1 ]]; then
    BSROOT=$(cd `dirname $0`; pwd)
else
    BSROOT=$1
fi

if [[ ! -d $BSROOT ]]; then
    echo "$BSROOT is not a directory"
    exit 2
fi

if [[ $BSROOT != /* ]]; then
  echo "bsroot path not start with / !"
  exit 1
fi

source $BSROOT/load_yaml.sh
load_yaml $BSROOT/config/cluster-desc.yml cluster_desc_

if [[ -e "$BSROOT/html/static/CentOS7/CentOS-7-x86_64-Everything-${cluster_desc_centos_version##*.}.iso" ]]; then
    if [[ ! -d "$BSROOT/html/static/CentOS7/dvd_content" ]]; then
        mkdir -p $BSROOT/html/static/CentOS7/dvd_content
    fi
    if [[ ! -f "$BSROOT/html/static/CentOS7/dvd_content/.treeinfo" ]]; then
        sudo mount -t iso9660 -o loop $BSROOT/html/static/CentOS7/CentOS-7-x86_64-Everything-${cluster_desc_centos_version##*.}.iso $BSROOT/html/static/CentOS7/dvd_content || { echo "Mount iso failed"; exit 1; }
    fi
fi

# Config Registry tls
mkdir -p /etc/docker/certs.d/bootstrapper:5000
rm -rf /etc/docker/certs.d/bootstrapper:5000/*
cp $BSROOT/tls/ca.pem /etc/docker/certs.d/bootstrapper:5000/ca.crt

if ! grep -q "127.0.0.1 bootstrapper" /etc/hosts
  then echo "127.0.0.1 bootstrapper" >> /etc/hosts
fi

docker rm -f bootstrapper > /dev/null 2>&1
docker rmi bootstrapper:latest > /dev/null 2>&1
docker load < $BSROOT/bootstrapper.tar > /dev/null 2>&1 || { echo "Docker can not load bootstrapper.tar!"; exit 1; }
docker run -d \
       --name bootstrapper \
       --net=host \
       --privileged \
       -v /var/run/docker.sock:/var/run/docker.sock \
       -v $BSROOT:/bsroot \
       bootstrapper ${cluster_desc_start_pxe} || { log fatal "Failed"; exit -1; }

# Sleep 3 seconds, waitting for registry started.
sleep 3


for DOCKER_IMAGE in $(set | grep '^cluster_desc_images_' | grep -o '".*"' | sed 's/"//g'); do
  DOCKER_TAR_FILE=$BSROOT/$(echo ${DOCKER_IMAGE}.tar | sed "s/:/_/g" |awk -F'/' '{print $NF}')
  printf "docker load & push $LOCAL_DOCKER_URL ... "
  LOCAL_DOCKER_URL=$cluster_desc_dockerdomain:5000/${DOCKER_IMAGE}
  docker load < $DOCKER_TAR_FILE >/dev/null 2>&1
  docker push $LOCAL_DOCKER_URL >/dev/null 2>&1
  echo "Done."
done

if [[ $cluster_desc_set_ntp == " y" ]]; then
docker rm -f ntpserver > /dev/null 2>&1
NTP_DOCKER_IMAGE=$cluster_desc_dockerdomain:5000/${cluster_desc_images_ntp}
docker run -d \
       --name ntpserver \
       --net=host \
       --privileged \
       $NTP_DOCKER_IMAGE || { echo "Failed"; exit -1; }
fi

