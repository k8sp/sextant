# auto-install

配置ceph集群的方法：

1. 用etcd写入/etc/ceph/下四个配置文件和/var/lib/ceph/bootstrap-rgw|bootstrap-mds|bootstrap-osd/ceph.keyring（三个）.
2. 用ceph自带kv

参考https://github.com/ceph/ceph-docker/blob/master/ceph-releases/jewel/ubuntu/14.04/daemon/README.md
