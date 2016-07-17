# 1.ceph架构

![](http://www.ibm.com/developerworks/cn/linux/l-ceph/figure1.gif)

参考：http://www.ibm.com/developerworks/cn/cloud/library/cl-openstackceph/
Ceph Client 是 Ceph 文件系统的用户。Ceph Metadata Daemon 提供了元数据服务器，而 Ceph Object Storage Daemon 提供了实际存储（对数据和元数据两者）。最后，Ceph Monitor 提供了集群管理。

与任何经典的分布式文件系统中一样，放入集群中的文件是条带化的，依据一种称为Ceph Controlled Replication Under
Scalable Hashing(CRUSH)的伪随机的数据分布算法放入集群节点中。


# 2.ceph部署
![](http://docs.ceph.com/docs/master/_images/ditaa-cffd08dd3e192a5f1d724ad7930cb04200b9b425.png)

一个ceph存储集群需要至少一个ceph monitor和至少两个ceph OSD Daemons，当运行ceph Filesystem clients时需要ceph Metadata Server。

1.ceph OSDs: Ceph OSD Daemon 存储数据，处理数据复制、恢复、填充、再平衡，通过检查其他Ceph OSD Daemons 的heartbeat来提供监测信息给Ceph Monitors。当集群做数据拷贝（默认是做数据的三个拷贝，但可调整）时，一个ceph存储集群需要至少两个ceph OSD Daemons来获得一个active+clean的状态。

2.Monitors: Ceph Monitor维护集群状态的映射，包括monitor映射，OSD映射，Placement Group(PG)映射和CRUSH映射，Ceph也维护Ceph Monitors、Ceph OSD Daemons和PGs中每个状态改变的历史（也叫epoch）

3.MDSs: Ceph Metadata Server(MDS)代表Ceph Filesystem存储metadata（注意Ceph Block Devices和Ceph Object Storage不用MDS），Ceph Metadata Servers使得POSIX文件系统用户可以执行基本指令包括ls, find等，而不会给Ceph存储集群造成大的负担。
Ceph将客户端数据作为对象存储在存储池中，通过CRUSH算法，Ceph计算哪个placement group应该保存对象，进一步计算哪个ceph OSD Daemon可以保存placement group。CRUSH算法使得Ceph存储集群可以做到规模化、再平衡、动态恢复。

用一个Ceph Monitor和两个Ceph OSD Daemons建立一个ceph Storage Cluster，一旦集群达到active+clean状态，通过增加第三个Ceph OSD Daemon、一个Metadata Server和两个Ceph Monitors来扩大集群，为了达到最好的结果，在你的admin node创建一个目录来保存配置文件和ceph-depoy为集群生成的keys。

# 3.1 Block Device Quick Start
也被称作RBD或RADOS，在此之前先保证Ceph Storage Cluster在active + clean状态

# 3.2 Filesystem Quick Start
Ceph Filesystem是一个POSIX-compliant文件系统，使用Ceph Storage Cluster来存储数据，它用同样的Ceph Storage Cluster系统作为Ceph Block Devices, Ceph Object Storage，with its S3和Swift APIs或native binding.

# 3.3 Object Storage Quick Start
基于RADOS，Ceph Storage Cluster是所有Ceph deployments的基础，对于通过众多客户端或网关（RADOSGW、RBD 或 CephFS）执行的每个操作，数据会进入 RADOS 或者可以从中读取数据，如下图1所示。Ceph Storage Cluster包括两种类型的daemons: 一个Ceph OSD Daemon(OSD)将数据作为对象存储到存储节点，一个Ceph Monitor(MON)维护集群映射的master版本，如下图2所示。一个Ceph Storage Cluster可能包括数千个Storage nodes，一个最小系统至少有一个Ceph Monitor和两个Ceph OSD Daemons来实现data replication。

图1
--
![](http://www.ibm.com/developerworks/cn/cloud/library/cl-openstackceph/figure01.png)
图2
--
![](http://www.ibm.com/developerworks/cn/cloud/library/cl-openstackceph/figure02.png)
-
Ceph Filesystem, Ceph Object Storage和 Ceph Block Devices从Ceph Storage Cluster中读写数据。
