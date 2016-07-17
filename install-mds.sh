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

# Run an MDS daemon
docker run -d --net=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph:/var/lib/ceph \
  -e CEPHFS_CREATE=1 ceph/daemon mds

