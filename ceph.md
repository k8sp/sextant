Ceph是一个统一的、分布式的文件存储系统，可以提供高性能，高可靠性和高可扩展性。“统一”是指Ceph系统可以提供对象存储、块存储和文件系统存储三种功能，“分布式”是指集群没有中心并且有集群规模有很好的可扩展性，节点间可以互相通信，动态实现数据的复制和分发，从而管理海量数据。
与任何经典的分布式文件系统中一样，放入集群中的文件是条带化的，依据一种称为Ceph Controlled Replication Under
Scalable Hashing(CRUSH)的伪随机的数据分布算法放入集群节点中。

# 1.Ceph架构
![](http://docs.ceph.com/docs/master/_images/stack.png)

底层是基础存储系统RADOS（Reliable Autonomic Distributed Object Store），基于RADOS，Ceph可以提供理论上没有上限的集群规模可扩展性。 上层与Ceph集群的交互方式有：

        1.RADOSGW(RADOS Gateway)是一种RESTful接口，应用程序与其通信，将对象存储在集群中。
        2.RBD(RODOS Block Device)是一个完全分布式的块存储。
        3.CephFS是一个分布式文件系统。
        4.LIBRADOS库允许程序直接访问RADOS。

# 2.Ceph存储集群
![](http://www.ibm.com/developerworks/cn/linux/l-ceph/figure1.gif)

在Ceph存储集群中，Ceph Client 是 Ceph 文件系统的用户客户端，Ceph Metadata Daemon 提供了元数据服务器，而 Ceph Object Storage Daemon 提供了实际存储（对数据和元数据两者）。最后，Ceph Monitor 提供了集群管理。

## 集群部署
Ceph Storage Cluster包括两种类型的daemons: 一个Ceph OSD Daemon(Ojbect Storage Device,OSD)将数据作为对象存储到存储节点，一个Ceph Monitor(MON)维护集群映射的master版本。

![](http://www.ibm.com/developerworks/cn/cloud/library/cl-openstackceph/figure02.png)

- <a>OSDs</a>: Ceph OSD Daemon 存储数据，处理数据复制、恢复、填充、再平衡，通过检查其他Ceph OSD Daemons 的heartbeat来提供监测信息给Ceph Monitors。当集群做数据拷贝（默认是做数据的三个拷贝，但可调整）时，一个ceph存储集群需要至少两个ceph OSD Daemons来获得一个active+clean的状态。

- <a>Mons</a>: Ceph Monitor维护集群状态的映射，包括monitor映射，OSD映射，Placement Group(PG)映射和CRUSH映射，Ceph也维护Ceph Monitors、Ceph OSD Daemons和PGs中每个状态改变的历史（也叫epoch）

- <a>MDSs</a>: Ceph Metadata Server(MDS)代表Ceph Filesystem存储metadata（注意Ceph Block Devices和Ceph Object Storage不用MDS），Ceph Metadata Servers使得POSIX文件系统用户可以执行基本指令包括ls, find等，而不会给Ceph存储集群造成大的负担。

一个Ceph存储集群需要至少一个Ceph Monitor和至少两个Ceph OSD Daemons，当运行Ceph Filesystem Clients时需要Ceph Metadata Server。

![](http://docs.ceph.com/docs/master/_images/ditaa-cffd08dd3e192a5f1d724ad7930cb04200b9b425.png)

Ceph将客户端数据作为对象存储在存储池中，通过CRUSH算法，Ceph计算哪个placement group应该保存对象，进一步计算哪个ceph OSD Daemon可以保存placement group。CRUSH算法使得Ceph存储集群可以做到规模化、再平衡、动态恢复。

用一个Ceph Monitor和两个Ceph OSD Daemons建立一个ceph Storage Cluster后，一旦集群达到active+clean状态，通过增加第三个Ceph OSD Daemon、一个Metadata Server和两个Ceph Monitors来扩大集群，为了达到最好的结果，在你的admin node创建一个目录来保存配置文件和ceph-depoy为集群生成的keys。

# 3 Ceph存储方式
Ceph支持三种存储Ceph Filesystem, Ceph Object Storage和 Ceph Block Devices，他们从Ceph Storage Cluster中读写数据。
## 3.1 Block Device
在此之前先保证Ceph Storage Cluster在active + clean状态，基于块的存储接口是最常见的用rotating media，如硬盘/CDs/floppy disks，来存储数据的方法。Ceph block devices是厚磁盘，大小可调节，在集群的多OSD中存储条带化数据。
rbd用于操作rados block device(RBD)镜像，被linux rbd driver和rbd storage driver用于QEMU/KVM。

## 3.2 Filesystem
Ceph Filesystem是一个POSIX-compliant文件系统，使用Ceph Storage Cluster来存储数据，它用同样的Ceph Storage Cluster系统作为Ceph Block Devices, Ceph Object Storage，with its S3和Swift APIs或native binding.用Ceph Filesystem需要在你的Ceph Storage Cluster上至少一个Ceph Metadata Server，Metadata Server(MDS)代表Ceph Filesystem存储metadata。

## 3.3 Object Storage
基于RADOS，Ceph Storage Cluster是所有Ceph deployments的基础，对于通过众多客户端或网关（RADOSGW、RBD 或 CephFS）执行的每个操作，数据会进入 RADOS 或者可以从中读取数据。Ceph Storage Cluster包括两种类型的daemons: 一个Ceph OSD Daemon(OSD)将数据作为对象存储到存储节点，一个Ceph Monitor(MON)维护集群映射的master版本。一个Ceph Storage Cluster可能包括数千个Storage nodes，一个最小系统至少有一个Ceph Monitor和两个Ceph OSD Daemons来实现data replication。

## 存储数据 STORING DATA
Ceph Storage Cluster从Ceph Clients接收数据，不管这个数据来自Ceph Bloak Device, Ceph Object Storage, Ceph Filesystem还是你通过librados创造的指令，它都将数据存储为对象，每个对象对应文件系统中的一个文件，被存储在Object Storage Device中。OSD Daemons在存储磁盘中执行读写操作
![](http://docs.ceph.com/docs/master/_images/ditaa-518f1eba573055135eb2f6568f8b69b4bb56b4c8.png)
##SCALABILITY AND HIGH AVAILABILITY
传统的有中心式集群，客户端与集群的中心节点交互，中心节点作为集群的单个入口，会对集群的性能和可扩展性造成限制。中心节点性能下降，相应的整个系统也会下降。Ceph通过使用CRUSH算法来去除集群中心性，作为一个无中心集群，使得客户端可以直接与Ceph OSD Daemons直接交互，Ceph OSD Daemons在其他节点上创建对象复制品来保证数据的安全和高利用性，也使用monitors集群来保证高利用性。

## CLUSTER MAP
- The Monitor Map
- The OSD Map
- The PG Map
- The CRUSH Map
- The MDS Map

## HIGH AVAILABILITY MONITORS

在Ceph Clients读写数据前，他们必须与Ceph Monitor通信来获取集群映射的最近拷贝。Ceph Storage Cluster可以只有单个monitor，然而，这样容易出问题。为了增加可靠性和容错性，Ceph支持monitors集群。在monitors集群中，延迟和其他故障会造成一个或多个monitor落后于集群当前的状态。因此，Ceph通常使用大部分monitors和Paxos算法来建立monitors关于当前集群状态的一致性。
### Monitor Config Reference
所有Ceph Storage Clusters至少一个monitor，monitor配置文件比较一致，你可以添加，删除或取代集群中的一个monitor。
Ceph Monitors有一个cluster map的“master copy”，Ceph Client仅仅通过链接一个Monitor，获取当前的cluster map就可以确定所有Monitors，OSD Daemons和Ceph Metadata SErvers的位置。计算目标位置的能力使得Ceph Client可以与Ceph OSD Daemons直接通信，这是Ceph高扩展性和高性能的一个重要方面。
Ceph Monitor的主要角色式维护cluster map的master copy，它将monitor services的所有变化写到单个Paxos，Paxos再写到key/value存储。
Monitors可以在同步操作期间查询cluster map的最近版本。

![](http://docs.ceph.com/docs/master/_images/ditaa-ae8fc6ae5b4014f064a0bed424507a7a247cd113.png)
Identify two numbers for your cluster:

    The number of OSDs.
    The total capacity of the cluster


#HIGH AVAILABILITY AUTHENTICATION
Ceph提供了cephx认证系统来认证用户和daemons，
## ceph docker集群配置

在某台机器上运行mon后，在/etc/ceph/和/var/lib/ceph生成配置文档，需要把配置文件分布到其他机器，在其他机器安装mon，
1. 在k8s集群中用etcd写入/etc/ceph/下四个配置文件和/var/lib/ceph/bootstrap-rgw|bootstrap-mds|bootstrap-osd/ceph.keyring三个keyring文件，实现集群中配置共享。这种方法的缺点是要指定第一台机器，不能全自动安装。
2. 用ceph自带kv，参考https://github.com/ceph/ceph-docker/blob/master/ceph-releases/jewel/ubuntu/14.04/daemon/README.md

# rbd-volume
https://github.com/ceph/ceph-docker/tree/master/rbd-volume
this Docker container will mount the requested RBD image to a volume.

1.systemctl start rbd-mount.service，挂载rbd volume到主机，docker通过volume来管理数据。

2.Dockerfile文件  
dockerfile是一种被Docker程序解释的脚本，Dockerfile有一条一条的指令组成，指令建议使用大写。
ENTRYPOINT设定容器启动时执行entrypoint.sh
运行docker build . 
/usr/bin/rbd map：映射rbd volume

/mountWait  
# ceph读取原理及磁盘挂载


## 参考文献
- <a>ceph官方文档</a> http://docs.ceph.com/docs/master/
- <a>Ceph: A Scalable, High-Performance Distributed File System</a>http://ceph.com/papers/weil-ceph-osdi06.pdf
- <a></a>http://www.ibm.com/developerworks/cn/cloud/library/cl-openstackceph/
- <a>rados论文</a> http://ceph.com/papers/weil-rados-pdsw07.pdf
- <a>CRUCH-Controlled,Scalable,Decentralized Placement of Replicated Data</a> http://ceph.com/papers/weil-crush-sc06.pdf
- <a>rbd-voluem</a> https://github.com/ceph/ceph-docker/tree/master/rbd-volume
