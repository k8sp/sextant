#!/usr/bin/env bash

KUBE_MASTER_HOSTNAME=00-25-90-c0-f7-80
BS_IP=10.10.14.253
setup_kubectl() {
  # Download kubectl binary
  wget --quiet -c -O "./kubectl" http://$BS_IP/static/kubectl
  chmod +x ./kubectl
  if [[ ! -d ~/bin ]]; then
    mkdir ~/bin
  fi
  cp ./kubectl ~/bin/
  # Configure kubectl
  echo $KUBE_MASTER_HOSTNAME
  kubectl config set-cluster default-cluster --server=http://$KUBE_MASTER_HOSTNAME:8080
  kubectl config set-context default-system --cluster=default-cluster
  kubectl config use-context default-system
}

setup_kubectl
