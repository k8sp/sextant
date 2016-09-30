#!/usr/bin/env bash

# Remember fullpaths, so that it is not required to run bsroot.sh from its local Git repo.
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

setup_kubectl() {
  input_dir=$1
  output_dir=$2
  ca_cert="$input_dir/ca.pem"
  admin_key="$output_dir/admin-key.pem"
  admin_cert="$output_dir/admin.pem"
  mkdir -p "$output_dir"
  # Download kubectl binary
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  hyperkube_version=`grep "hyperkube:" "$input_dir/cluster-desc.yml" | grep -o '".*hyperkube.*:.*"' | sed 's/".*://; s/"//'`
  wget --quiet -c -O "$output_dir/kubectl" https://storage.googleapis.com/kubernetes-release/release/$hyperkube_version/bin/$OS/amd64/kubectl
  chmod +x kubectl/kubectl
  # Generate TLS keys
  openssl genrsa -out "$admin_key" 2048
  openssl req -new -key "$admin_key" -out "$output_dir/admin.csr" -subj "/CN=kube-admin"
  openssl x509 -req -in "$output_dir/admin.csr" -CA "$input_dir/ca.pem" -CAkey "$input_dir/ca-key.pem" -CAcreateserial -out "$admin_cert" -days 365
  # Configure kubectl
  kube_master_hostname=`head -n $(grep -n 'kube_master\s*:\s*y' "$input_dir/cluster-desc.yml" | cut -d: -f1) "$input_dir/cluster-desc.yml" | grep mac: | tail | grep -o '..:..:..:..:..:..' | tr ':' '-'`
  echo $kube_master_hostname
  kubectl config set-cluster default-cluster --server=https://$kube_master_hostname --certificate-authority=${ca_cert}
  kubectl config set-credentials default-admin --certificate-authority=${ca_cert} --client-key=${admin_key} --client-certificate=${admin_cert}
  kubectl config set-context default-system --cluster=default-cluster --user=default-admin
  kubectl config use-context default-system
}

if [[ "$#" -ne 2 ]]; then
    echo "Usage: bsroot.sh <input_dir> <output_dir>"
    echo
    echo "<input_dir> must contain the following files:"
    echo "- ca.pem"
    echo "- ca-key.pem"
    echo "- cluster-desc.yml"
    echo "<output_dir> will have the following output files:"
    echo "- kubectl: the binary file"
    echo "- admin.pem and admin-key.pem: TLS keys for kubectl to communicate with kube-master"
    exit 1
fi

setup_kubectl $(realpath $1) $(realpath $2)
