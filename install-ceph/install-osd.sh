#!/bin/bash

devices=$(sudo parted -l |grep 'Disk' |awk '!/boot/{if(NR%2 == 0) print x};{x=$2}'|sed 's/:$//')

# Run OSD daemon for each device
for device in devices
do
  echo "Run OSD daemon on: $device"
  docker run -d --pid=host --net=host --privileged=true \
    -v /etc/ceph:/etc/ceph \
    -v /var/lib/ceph:/var/lib/ceph \
    -v /dev:/dev \
    -e KV_TYPE=etcd \
    -e OSD_FORCE_ZAP=1 \
    -e OSD_DEVICE=$device \
    ceph/daemon osd_ceph_disk
done
