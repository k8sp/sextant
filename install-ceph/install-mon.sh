#!/bin/bash

docker_hub=$1
if [[ ! -z $docker_hub ]]; then
  docker_hub=$docker_hub"/"
fi

CEPH_CLUSTER_NAME=ceph
CEPH_MON_DOCKER_NAME=ceph_mon
CEPH_MDS_DOCKER_NAME=ceph_mds
CEPH_IMG_TAG=tag-build-master-jewel-ubuntu-14.04-fix370

# cephx enabled ?
etcdctl get /ceph-config/$CEPH_CLUSTER_NAME/auth/cephx
# populate kvstore
# NOTICE: put OSD_JOURNAL_SIZE settings in a default file
# as of: https://github.com/ceph/ceph-docker/blob/master/ceph-releases/jewel/ubuntu/14.04/daemon/entrypoint.sh#L173
# NOTICE: use docker run --rm to ensure container is deleted after execution
if [ $? -ne 0 ]; then
  echo "Enable cephx."
  if [[ ! -d "/etc/ceph" ]]; then
    mkdir -p /etc/ceph
  fi
  cat > $BSROOT/tftpboot/pxelinux.cfg/default <<EOF
# auth
/auth/cephx true
EOF
  docker run --rm --net=host \
    --name ceph_kvstore \
    -v /etc/ceph/:/etc/ceph/ \
    -v /var/lib/ceph/:/var/lib/ceph \
    -e CLUSTER=$CEPH_CLUSTER_NAME \
    -e KV_TYPE=etcd \
    -e KV_IP=127.0.0.1 \
    -e KV_PORT=2379 \
    -e OSD_JOURNAL_SIZE=<JOURNAL_SIZE> \
    --entrypoint=/bin/bash \
    "$docker_hub"ceph/daemon populate_kvstore
fi

# MON
if docker ps -a | grep -q $CEPH_MON_DOCKER_NAME ; then
  echo "docker container $CEPH_MON_DOCKER_NAME exists, start it now"
  docker start $CEPH_MON_DOCKER_NAME
else
  # Start the ceph monitor
  echo "docker container $CEPH_MON_DOCKER_NAME doesn't exist, run it now"
  docker run -d --restart=on-failure --net=host \
    --name $CEPH_MON_DOCKER_NAME \
    -v /etc/ceph:/etc/ceph \
    -v /var/lib/ceph/:/var/lib/ceph \
    -e CLUSTER=$CEPH_CLUSTER_NAME \
    -e KV_TYPE=etcd \
    -e NETWORK_AUTO_DETECT=4 \
    --entrypoint=/entrypoint.sh \
    "$docker_hub"ceph/daemon mon
fi

# MDS
if docker ps -a | grep -q $CEPH_MDS_DOCKER_NAME ; then
  echo "docker container $CEPH_MDS_DOCKER_NAME exists, start it now"
  docker start $CEPH_MDS_DOCKER_NAME
else
  # Start the ceph monitor
  echo "docker container $CEPH_MDS_DOCKER_NAME doesn't exist, run it now"
  docker run -d --restart=on-failure --net=host \
    --name ceph_mds \
    -e CLUSTER=$CEPH_CLUSTER_NAME \
    -e CEPHFS_CREATE=1 \
    -e KV_TYPE=etcd \
    --entrypoint=/entrypoint.sh \
    "$docker_hub"ceph/daemon mds
fi
