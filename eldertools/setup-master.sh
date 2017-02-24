#!/bin/bash
set -e

download_packages() {
  wget -c https://github.com/coreos/etcd/releases/download/v2.3.8/etcd-v2.3.8-linux-amd64.tar.gz
  tar xzf etcd-v2.3.8-linux-amd64.tar.gz
  ln -s etcd-v2.3.8-linux-amd64 etcd

  mkdir flannel
  wget -c https://github.com/coreos/flannel/releases/download/v0.7.0/flannel-v0.7.0-linux-amd64.tar.gz
  # got "flanneld" binary
  tar xzf flannel-v0.7.0-linux-amd64.tar.gz

  mkdir kubelet
  wget --quiet -c -N -O $BSROOT/html/static/kubelet https://dl.dropboxusercontent.com/u/27178121/kubelet.v1.6.0/kubelet

  mkdir images
  for $i in "pineking/hyperkube-amd64:v1.6.0-alpha-2aa99" "typhoon1986/pause-amd64:3.0" "pineking/kube-dnsmasq-amd64:1.4" "pineking/kubedns-amd64:1.9"
  do
    docker pull $i
    IMG_NAME=$( echo $i | awk -F "/" '{print $NF}' | sed 's/-/_/g' )
    docker save $i > images/$IMG_NAME.tar
  done
}

push_docker_images() {
  arg1=$1
  if [ -n $1 ]; then
    echo "push_docker_images() call must pass the docker registry url."
    exit 1
  fi
  for $i in "pineking/hyperkube-amd64:v1.6.0-alpha-2aa99" "typhoon1986/pause-amd64:3.0" "pineking/kube-dnsmasq-amd64:1.4" "pineking/kubedns-amd64:1.9"
  do
    docker tag $i $arg1/$i
    docker push $arg1/$i
  done
}
