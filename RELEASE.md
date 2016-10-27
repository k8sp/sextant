## Release 0.2

- Introduce the idea of `bsroot`, which is a directory containing everything we need to collect from the Internet and will be shipped to the *bootstrapper* server in the cluster.  After these, the installation, configuration and auto-upgrade of the cluster are from the bootstrapper server, which has PXE service that boots new nodes and installs CoreOS into them, which has Docker registry service which delivers basic images like Kubernetes, Ceph, flanneld, etcd, etc, which has dnsmasq which provides DNS and DHCP service (as part of the PXE service).

- Add `vm-cluster` which provides a test environment using Vagrant and multiple VMs.

- Add support of Ceph.

- Significantly removed unnecessary sub-directories

## Release 0.1

Initial release of Sextant.

<!--  LocalWords:  bsroot bootstrapper PXE Ceph flanneld etcd dnsmasq
 -->
<!--  LocalWords:  DHCP vm VMs
 -->
