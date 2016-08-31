#!/bin/bash

# This function converts a net mask to an CIDR.
# To start a Ceph monitor by running the docker container ceph/daemon, an
# environment variable CEPH_PUBLIC_NETWORK is needed in the form of
# <IP address><CIDR>. We can get the IP address and net mask by some command
# line tools, but we can't directly get the CIDR, so we provide this function to
# convert the net mask to CIDR.
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
    ["0.0.0.0"]="/0" \
    )
  echo "${convert_table[$netmask]}"
}

interface=$(ip route | grep default | awk '{print $5}')
ip_addr=$(ifconfig $interface | grep '\binet\b' | awk '{print $2}')
net_mask=$(ifconfig $interface | grep '\binet\b' | awk '{print $4}')

CEPH_CLUSTER_NAME=ceph
CEPH_MON_DOCKER_NAME=ceph_mon
CEPH_MDS_DOCKER_NAME=ceph_mds

# cephx enabled ?
etcdctl get /ceph-config/$CEPH_CLUSTER_NAME/auth/cephx
# populate kvstore
if [ $? -eq 0 ]; then
  echo "Enable cephx."
  docker run -d --net=host \
    --name ceph_kvstore \
    -e CLUSTER=$CEPH_CLUSTER_NAME \
    -e KV_TYPE=etcd \
    -e KV_IP=127.0.0.1 \
    -e KV_PORT=2379 \
    ceph/daemon populate_kvstore
  docker rm -f ceph_kvstore
fi

# MON
if docker ps -a | grep -q $CEPH_MON_DOCKER_NAME ; then
  echo "docker container $CEPH_MON_DOCKER_NAME exists, start it now"
  docker start $CEPH_MON_DOCKER_NAME
else
  # Start the ceph monitor
  echo "docker container $CEPH_MON_DOCKER_NAME doesn't exist, run it now"
  docker run -d --net=host \
    --name $CEPH_MON_DOCKER_NAME \
    -v /etc/ceph:/etc/ceph \
    -v /var/lib/ceph/:/var/lib/ceph \
    -e CLUSTER=$CEPH_CLUSTER_NAME
    -e KV_TYPE=etcd \
    -e MON_IP=$ip_addr \
    -e CEPH_PUBLIC_NETWORK=$ip_addr$(netmask_to_cidr $net_mask) \
    ceph/daemon mon
fi

# MDS
if docker ps -a | grep -q $CEPH_MDS_DOCKER_NAME ; then
  echo "docker container $CEPH_MDS_DOCKER_NAME exists, start it now"
  docker start $CEPH_MDS_DOCKER_NAME
else
  # Start the ceph monitor
  echo "docker container $CEPH_MDS_DOCKER_NAME doesn't exist, run it now"
  docker run -d --net=host \
    --name ceph_mds \
    -e CLUSTER=$CEPH_CLUSTER_NAME \
    -e CEPHFS_CREATE=1 \
    -e KV_TYPE=etcd \
    ceph/daemon mds
fi

