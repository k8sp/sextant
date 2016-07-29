
本文简述使用ceph/ceph-docker项目<sup>[docker](#docker)</sup>创建的Docker image来部署Ceph机群的方法。
# 在CoreOS上配置Ceph集群

Ceph是一个统一的、分布式的文件存储系统，可以提供高性能，高可靠性和高可扩展性。“统一”是指Ceph系统可以提供对象存储、块存储和文件系统存储三种功能，“分布式”是指集群没有中心并且有集群规模有很好的可扩展性，节点间可以互相通信，动态实现数据的复制和分发，从而管理海量数据。
与任何经典的分布式文件系统中一样，放入集群中的文件是条带化的，依据一种称为Ceph Controlled Replication Under
Scalable Hashing(CRUSH)的伪随机的数据分布算法<sup>[crush](#crush)</sup>放入集群节点中。

## Ceph架构介绍
![](http://docs.ceph.com/docs/master/_images/stack.png)

底层是基础存储系统RADOS（Reliable Autonomic Distributed Object Store），基于RADOS，Ceph可以提供理论上没有上限的集群规模可扩展性。 上层与Ceph集群的交互方式有：

  1. RADOSGW(RADOS Gateway)是一种RESTful接口，应用程序与其通信，将对象存储在集群中。
  2. RBD(RODOS Block Device)是一个完全分布式的块存储。
  3. CephFS是一个分布式文件系统。
  4. LIBRADOS库允许程序直接访问RADOS。

## Ceph存储集群
![](http://www.ibm.com/developerworks/cn/linux/l-ceph/figure1.gif)

在Ceph存储集群中，Client 是 Ceph 文件系统的用户客户端，Metadata Daemon(MDS)提供了元数据服务器，而Object Storage Daemon(OSD) 提供了实际存储（对数据和元数据两者），Monitor(MON)提供了集群管理。

### 集群部署
Ceph Storage Cluster包括两种类型的daemons: OSD daemon将数据作为对象存储到存储节点，MON daemon维护集群映射的master版本。

![](http://www.ibm.com/developerworks/cn/cloud/library/cl-openstackceph/figure02.png)

- OSDs: OSD daemon存储数据，处理数据复制、恢复、填充、再平衡，通过检查其他Ceph OSD daemons 的heartbeat来提供监测信息给Ceph monitors。当集群做数据拷贝（默认是做数据的三个拷贝，但可调整）时，一个ceph存储集群需要至少两个ceph OSD daemons来获得一个active+clean的状态。

- Mons: monitor维护集群状态的映射，包括monitor映射，OSD映射，Placement Group(PG)映射和CRUSH映射，Ceph也维护Mons、OSDs 和PGs中每个状态改变的历史（也叫epoch）

- MDSs: metadata server代表Filesystem存储metadata（注意Ceph block devices和Ceph object storage不用MDS），Ceph metadata servers使得POSIX文件系统用户可以执行基本指令包括ls, find等，而不会给Ceph存储集群造成大的负担。

一个Ceph存储集群需要至少一个Ceph monitor和至少两个Ceph OSD，当运行Ceph filesystem clients时需要MDS。

![](http://docs.ceph.com/docs/master/_images/ditaa-cffd08dd3e192a5f1d724ad7930cb04200b9b425.png)

Ceph将客户端数据作为对象存储在存储池中，通过CRUSH算法，Ceph计算哪个placement group应该保存对象，进一步计算哪个ceph OSD daemon可以保存placement group。CRUSH算法使得Ceph存储集群可以做到规模化、再平衡、动态恢复。

用一个Monitor和两个OSD daemons建立一个ceph storage cluster后，一旦集群达到active+clean状态，通过增加第三个OSD、一个MDS和两个Mon来扩大集群，为了达到最好的结果，在你的admin node创建一个目录来保存配置文件和ceph-depoy为集群生成的keys。

## Ceph存储方式
Ceph支持三种存储Ceph filesystem, Ceph object storage和 Ceph block devices，他们从Ceph storage cluster中读写数据。
### Block device
在此之前先保证Ceph storage cluster在active + clean状态，基于块的存储接口是最常见的用rotating media，如硬盘/CDs/floppy disks，来存储数据的方法。Ceph block devices是厚磁盘，大小可调节，在集群的多OSD中存储条带化数据。
rbd用于操作rados block device(RBD)镜像，被linux rbd driver和rbd storage driver用于QEMU/KVM。

### Filesystem
Filesystem是一个POSIX-compliant文件系统，使用Ceph storage cluster来存储数据，它用同样的Ceph storage cluster系统作为Ceph block devices, Ceph object storage，with its S3和Swift APIs或native binding.用Filesystem需要在你的Ceph storage Cluster上至少有一个MDS，MDS代表Filesystem存储metadata。

### Object storage
基于RADOS，Ceph storage cluster是所有Ceph deployments的基础，对于通过众多客户端或网关（RADOSGW、RBD 或 CephFS）执行的每个操作，数据会进入 RADOS 或者可以从中读取数据。Ceph storage cluster包括两种类型的daemons: 一个Ceph OSD 将数据作为对象存储到存储节点，一个Ceph monitor维护集群映射的master版本。一个Ceph storage cluster可能包括数千个Storage nodes，一个最小系统至少有一个Ceph monitor和两个Ceph OSD来实现data replication。


Ceph storage cluster从Ceph clients接收数据，不管这个数据来自Ceph bloak device, Ceph object storage, Ceph filesystem还是你通过librados创造的指令，它都将数据存储为对象，每个对象对应文件系统中的一个文件，被存储在Object storage device中。OSD在存储磁盘中执行读写操作，图1所示
#### <a name=f1>图1</a>
![](http://docs.ceph.com/docs/master/_images/ditaa-518f1eba573055135eb2f6568f8b69b4bb56b4c8.png)
###可扩展性和高可利用性
传统的有中心式集群，客户端与集群的中心节点交互，中心节点作为集群的单个入口，会对集群的性能和可扩展性造成限制。中心节点性能下降，相应的整个系统也会下降。Ceph通过使用CRUSH算法来去除集群中心性，作为一个无中心集群，使得客户端可以直接与OSD daemons直接交互，OSD daemons在其他节点上创建对象复制品来保证数据的安全和高利用性，也使用monitors集群来保证高利用性。

### 集群映射
- The Monitor map：包括集群fsid，每个monitor的位置，命名地址和端口号，它指明集群当前的epoch，map的创建时间和最后修改时间，通过执行ceph mon dump命令来查看
- The OSD map：包括集群fsid，map的创建和上次修改时间，pools列表，复制规模，PG数量，OSDs列表和状态。通过执行ceph osd dump命令来查看
- The PG map：包括PG版本，时间戳，上次OSD map的epoch，全比例，每个PG的详细信息，比如PG ID，UP Set，Acting Set，PG状态和每个pool的数据使用统计
- The CRUSH map：包括存储设备，故障域层级，存储数据时遍历层级的规则。
- The MDS map：包含当前MDS map epoch，map创建，最后修改时间，存储元数据的pool，元数据服务器列表及其状态。执行ceph mds dump查看MDS map。
![](http://docs.ceph.com/docs/master/_images/ditaa-ae8fc6ae5b4014f064a0bed424507a7a247cd113.png)

### 高可用性monitors

在Clients读写数据前，他们必须与Monitor通信来获取集群映射的最近拷贝。Ceph storage cluster可以只有单个monitor，然而，这样容易出问题。为了增加可靠性和容错性，Ceph支持monitors集群。在monitors集群中，延迟和其他故障会造成一个或多个monitor落后于集群当前的状态。因此，Ceph通常使用大部分monitors和Paxos算法来建立monitors关于当前集群状态的一致性。
### Monitor配置
所有Ceph storage clusters至少一个monitor，monitor配置文件比较一致，你可以添加，删除或取代集群中的一个monitor。
Ceph Monitors有一个cluster map的“master copy”，Client仅仅通过链接一个Monitor，获取当前的cluster map就可以确定所有Mon，OSD ,MDS的位置。计算目标位置的能力使得Client可以与OSD daemons直接通信，这是Ceph高扩展性和高性能的一个重要方面。
Monitor的主要角色式维护cluster map的master copy，它将monitor services的所有变化写到单个Paxos，Paxos再写到key/value存储。
Monitors可以在同步操作期间查询cluster map的最近版本。
### 一致性
Clients和其他Ceph daemons通过Ceph配置文件发现monitors，monitors通过monitor map(monmap)来发现彼此，而不是配置文件。对Ceph monitor有更新的操作后，Ceph通过一个被称作Paxos的分布式一致性算法来相应修改monmap。
### 数据存储
Monitors默认存储数据的路径为 /var/lib/ceph/mon/$cluster-$id，这个路径不建议修改。为了是的Ceph storage cluster有最好的性能，推荐在分开的hosts上运行Monitors，从OSD daemons中驱动。
Ceph0.59之前的版本，将数据存储在文件中，可以通过ls和cat查看，但没有强一致性。以后的版本，Monitors将数据存储为键值对，
### 集群容量
假设一个集群中，有33个Ceph Nodes, 每台主机有一个OSD Daemon, 每个OSD Daemon从3TB驱动中读写数据，这样集群最大的实际容量是99TB，如果mon osd full ratio为0.95，当剩余容量到5TB时，集群就不会容许Clients继续读写数据，集群的可操作容量为95TB，而非99TB。
### 高可用性认证
Ceph提供了cephx认证系统来认证用户和daemons，Client和Monitor的key文件分别是/etc/ceph/ceph.client.admin.keyring和ceph.mon.keyring.
## Ceph Docker集群配置

在某台机器上运行mon后，在/etc/ceph/和/var/lib/ceph生成配置文档，需要把配置文件分布到其他机器。
1. 在k8s集群中用etcd写入/etc/ceph/下四个配置文件和/var/lib/ceph/bootstrap-rgw|bootstrap-mds|bootstrap-osd/ceph.keyring三个keyring文件，其他机器安装mon时从etcd中读取。这种方法的缺点是要指定第一台机器，不能全自动安装。
2. ceph支持etcd和consul两种KV backends，所有的机器执行相同的脚本，实现全自动化安装。

### rbd volume挂载
根据ceph/ceph-docker项目，通过Docker容器将Ceph RBD volume挂载到主机。
运行docker build . 
未完..


## 参考文献
- ceph官方文档 http://docs.ceph.com/docs/master/
- Ceph论文: A Scalable, High-Performance Distributed File System http://ceph.com/papers/weil-ceph-osdi06.pdf
- http://www.ibm.com/developerworks/cn/cloud/library/cl-openstackceph/
- rados论文 http://ceph.com/papers/weil-rados-pdsw07.pdf
- CRUCH-Controlled,Scalable,Decentralized Placement of Replicated Data http://ceph.com/papers/weil-crush-sc06.pdf
- rbd-volume https://github.com/ceph/ceph-docker/tree/master/rbd-volume
- docker https://github.com/ceph/ceph-docker/blob/master/ceph-releases/jewel/ubuntu/14.04/daemon/README.md
