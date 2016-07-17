#!/bin/bash

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


devices=$(sudo parted -l |grep 'Disk' |awk '!/boot/{if(NR%2 == 0) print x};{x=$2}'|sed 's/:$//')

# Run OSD daemon for each device
for device in devices
do
  echo "Run OSD daemon on: $device"
  docker run -d --net=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph:/var/lib/ceph \
    -v /dev:/dev --privileged=true -e OSD_FORCE_ZAP=1 \
    -e OSD_DEVICE=$device ceph/daemon osd_ceph_disk
done
