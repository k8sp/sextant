#!/usr/bin/env bash

# Remember fullpaths, so that it is not required to run bsroot.sh from its local Git repo.
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

KUBE_MASTER_HOSTNAME=<KUBE_MASTER_HOSTNAME>
HYPERKUBE_VERSION=<HYPERKUBE_VERSION>

setup_kubectl() {
  # Download kubectl binary
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  wget --quiet -c -O "./kubectl" https://storage.googleapis.com/kubernetes-release/release/$HYPERKUBE_VERSION/bin/$OS/amd64/kubectl
  chmod +x ./kubectl
  # Configure kubectl
  echo $KUBE_MASTER_HOSTNAME
  ./kubectl config set-cluster default-cluster --server=http://$KUBE_MASTER_HOSTNAME:8080
  ./kubectl config set-context default-system --cluster=default-cluster
  ./kubectl config use-context default-system
}

setup_kubectl
