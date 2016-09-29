#!/bin/bash

# start_bootstrapper_container.sh load docker image from bsroot and
# then push them to registry
if [[ "$#" -gt 1 ]]; then
    echo "Usage: start_bootstrapper_contaienr.sh [bsroot-path]"
    exit 1
elif [[ "$#" -ne 1 ]]; then
    BSROOT=/bsroot
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

if [[ $1 != /* ]]; then
  echo "bsroot path not start with / !"
  exit 1
fi
# push k8s images to registry from bsroot
BOOTATRAPPER_DOMAIN=`grep "dockerdomain:" $BSROOT/config/cluster-desc.yml | awk '{print $2}' | sed 's/"//g' | sed 's/ //g'`
HYPERKUBE_VERSION=`grep "hyperkube_version:" $BSROOT/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`
PAUSE_VERSION=`grep "pause_version:" $BSROOT/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`
FLANNEL_VERSION=`grep "flannel_version:" $BSROOT/config/cluster-desc.yml | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`

# Config Registry tls
mkdir -p /etc/docker/certs.d/bootstrapper:5000
rm -rf /etc/docker/certs.d/bootstrapper:5000/*
cp $BSROOT/tls/ca.pem /etc/docker/certs.d/bootstrapper:5000/ca.crt

echo "127.0.0.1 bootstrapper" >> /etc/hosts

docker load < $BSROOT/bootstrapper.tar > /dev/null 2>&1 || { echo "Docker can not load bootstrapper.tar!"; exit 1; }
docker run -d --net=host \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $BSROOT:/bsroot \
  bootstrapper

# Sleep 3 seconds, waitting for registry started.
sleep 3

DOCKER_IMAGES=("typhoon1986/hyperkube-amd64:${HYPERKUBE_VERSION}" \
  "typhoon1986/pause:${PAUSE_VERSION}" \
  "typhoon1986/flannel:${FLANNEL_VERSION}" \
  "yancey1989/nginx-ingress-controller:0.8.3" \
  "yancey1989/kube2sky:1.14" \
  "typhoon1986/exechealthz:1.0" \
  "yancey1989/kube-addon-manager-amd64:v5.1" \
  "typhoon1986/skydns:latest");
len=${#DOCKER_IMAGES[@]}
for ((i=0;i<len;i++)); do
  DOCKER_IMAGE=${DOCKER_IMAGES[i]}
  DOCKER_TAR_FILE=$BSROOT/$(echo ${DOCKER_IMAGE}.tar | sed "s/:/_/g" |awk -F'/' '{print $2}')
  DOCKER_TAG_NAME=`echo $BOOTATRAPPER_DOMAIN:5000/${DOCKER_IMAGE} | awk -F'/' '{print $1"/"$3}'`
  docker load < $DOCKER_TAR_FILE
  docker tag $DOCKER_IMAGE $DOCKER_TAG_NAME
  docker push $DOCKER_TAG_NAME
done
