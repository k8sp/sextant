#!/bin/bash

docker_hub=$1
if [[ ! -z $docker_hub  ]]; then
  docker_hub=$docker_hub"/"
fi

#Obtain devices
devices=$(lsblk -l |awk '$6=="disk"{print $1}')
systemdevice=$(lsblk -l |awk '$7=="/usr"{print $1}' |sed 's/[0-9]\+$//')

CEPH_CLUSTER_NAME=ceph

# Run OSD daemon for each device
for d in $devices
do
  if [[ $d != $systemdevice ]]; then
    device="/dev/$d"
    CEPH_OSD_DOCKER_NAME=ceph_osd_${d}
    docker rm $CEPH_OSD_DOCKER_NAME
    docker run -d --pid=host --net=host --privileged=true \
      --name $CEPH_OSD_DOCKER_NAME \
      -v /etc/ceph:/etc/ceph \
      -v /var/lib/ceph:/var/lib/ceph \
      -v /dev:/dev \
      -e KV_TYPE=etcd \
      -e CLUSTER=$CEPH_CLUSTER_NAME \
      -e OSD_DEVICE=${device} \
      "$docker_hub"ceph/daemon:tag-build-master-jewel-ubuntu-14.04-fix370 /bin/bash -x /entrypoint.sh osd
  fi
done
