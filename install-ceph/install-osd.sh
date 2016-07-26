#!/bin/bash

#Obtain devices
devices=$(lsblk -l |awk '$6=="disk"{print $1}')
systemdevice=$(lsblk -l |awk '$7=="/usr"{print $1}' |sed 's/[0-9]\+$//')

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
      -e OSD_FORCE_ZAP=1 \
      -e OSD_DEVICE=${device} \
      ceph/daemon osd
  fi
done

