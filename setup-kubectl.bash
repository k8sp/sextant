#!/usr/bin/env bash

KUBE_MASTER_HOSTNAME=<KUBE_MASTER_HOSTNAME>

setup_kubectl() {
  # Download kubectl binary
  wget --quiet -c -O "./kubectl" https://dl.dropboxusercontent.com/u/27178121/kubelet.v1.6.0/kubectl
  chmod +x ./kubectl
  # Configure kubectl
  echo $KUBE_MASTER_HOSTNAME
  ./kubectl config set-cluster default-cluster --server=http://$KUBE_MASTER_HOSTNAME:8080
  ./kubectl config set-context default-system --cluster=default-cluster
  ./kubectl config use-context default-system
}

setup_kubectl
