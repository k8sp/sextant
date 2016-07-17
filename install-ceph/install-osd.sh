#!/bin/bash

# Run an OSD daemon, use /dev/sdb for now
docker run -d --pid=host --net=host \
  -v /etc/ceph:/etc/ceph-v /var/lib/ceph:/var/lib/ceph \
  -v /dev:/dev --privileged=true \
  -e KV_TYPE=etcd \
  -e OSD_FORCE_ZAP=1 \
  -e OSD_DEVICE=/dev/sdb ceph/daemon osd_ceph_disk
