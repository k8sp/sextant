#!/bin/bash

interface=$(ip route | grep default | awk '{print $5}')
net_mask=$(ip a show $interface | grep '\binet\b' | awk '{print $2}');
ip_addr=${net_mask%%/*}

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

