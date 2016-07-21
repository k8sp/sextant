#!/bin/bash

#Obtain devices
devices=$(lsblk -l |awk '$6=="disk"{print $1}')
systemdevice=$(lsblk -l |awk '$7=="/usr"{print $1}' |sed 's/[0-9]\+$//')

# Run OSD daemon for each device
for a in $devices
do
  if [[ $a != $systemdevice ]]; then
    device="/dev/$a"
    echo "Run OSD daemon on: $device"
    docker run -d --pid=host --net=host --privileged=true \
      -v /etc/ceph:/etc/ceph \
      -v /var/lib/ceph:/var/lib/ceph \
      -v /dev:/dev \
      -e KV_TYPE=etcd \
      -e OSD_FORCE_ZAP=1 \
      -e OSD_DEVICE=$device \
      ceph/daemon osd_ceph_disk
  fi
done
