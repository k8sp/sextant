#!/bin/bash

function netmask_to_cidr {
  local netmask=$1
  declare -A convert_table=( \
    ["255.255.255.255"]="/32" \
    ["255.255.255.254"]="/31" \
    ["255.255.255.252"]="/30" \
    ["255.255.255.248"]="/29" \
    ["255.255.255.240"]="/28" \
    ["255.255.255.224"]="/27" \
    ["255.255.255.192"]="/26" \
    ["255.255.255.128"]="/25" \
    ["255.255.255.0"]="/24" \
    ["255.255.254.0"]="/23" \
    ["255.255.252.0"]="/22" \
    ["255.255.248.0"]="/21" \
    ["255.255.240.0"]="/20" \
    ["255.255.224.0"]="/19" \
    ["255.255.192.0"]="/18" \
    ["255.255.128.0"]="/17" \
    ["255.255.0.0"]="/16" \
    ["255.254.0.0"]="/15" \
    ["255.252.0.0"]="/14" \
    ["255.248.0.0"]="/13" \
    ["255.240.0.0"]="/12" \
    ["255.224.0.0"]="/11" \
    ["255.192.0.0"]="/10" \
    ["255.128.0.0"]="/9" \
    ["255.0.0.0"]="/8" \
    ["254.0.0.0"]="/7" \
    ["252.0.0.0"]="/6" \
    ["248.0.0.0"]="/5" \
    ["240.0.0.0"]="/4" \
    ["224.0.0.0"]="/3" \
    ["192.0.0.0"]="/2" \
    ["128.0.0.0"]="/1" \
    ["0.0.0.0"]="/0"\
    )
  echo "${convert_table[$netmask]}"
}

# Get the keyring and config files from etcd
for f in \
  /etc/ceph/ceph.client.admin.keyring \
  /etc/ceph/ceph.conf \
  /etc/ceph/ceph.mon.keyring \
  /etc/ceph/monmap \
  /var/lib/ceph/bootstrap-mds/ceph.keyring \
  /var/lib/ceph/bootstrap-osd/ceph.keyring \
  /var/lib/ceph/bootstrap-rgw/ceph.keyring
do
  sudo mkdir -p $(dirname $f)
  etcdctl get /unisound/ceph-dist$f | base64 --decode | sudo tee $f >/dev/null
done

interface=$(ip route | grep default | awk '{print $5}')
ip_addr=$(ifconfig $interface | grep '\binet\b' | awk '{print $2}')
net_mask=$(ifconfig $interface | grep '\binet\b' | awk '{print $4}')

# Start the ceph monitor
sudo docker run -d --net=host \
  -v /etc/ceph:/etc/ceph \
  -v /var/lib/ceph/:/var/lib/ceph \
  -e MON_IP=$ip_addr \
  -e CEPH_PUBLIC_NETWORK=$ip_addr$(netmask_to_cidr $net_mask) \
  ceph/daemon mon

