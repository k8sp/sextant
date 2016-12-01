# CentOS 自动安装与配置

## 目的

实现基于 CentOS 的 Kubernetes 集群及其附属组件和服务的自动安装与配置，在实现的过程中，尽量复用基于 CoreOS 安装配置的已有的脚本和功能模块。

## 方案

### 设计 Bootstrapper server 的功能
为了让机群中的机器可以全自动地安装  CentOS 和Kubernetes，并且加入Kubernete机群，我们需要将机群中一台有 static IP 的机器上，称为bootstrapper server。Bootstrapper server 具有以下功能：
  * 自动安装 CentOS
  * 自动配置 CentOS
  * 自动安装 Kubernetes
  * 为集群提供 DHCP + DNS 服务
  * 自动安装 GPU 驱动 （可选）
  * 提供 Ceph 存储服务 （可选）

### 实现 Bootstrapper server 的功能

为了方便地实现 Bootstrapper server 上述功能，我们将其封装在一个 Docker image 里，称为*bootstrapper image*。这个image在执行的时候，会挂载 Bootstrapper server 上本地文件系统里的一个目录，里面有上述各服务的配置文件，以及它们需要依赖的其他文件。为了方便，我们称这个目录为`bsroot`目录。

为了生成bsroot目录的内容，我们要运行 `bsroot_centos.sh`。这个脚本读取一个机群描述文件 `cluster-desc.yml`，分析其中信息，生成配置文件。下面分别介绍 `bsroot_centos.sh` 如何实现 Bootstrapper server 各个功能。

* 自动安装 CentOS

  此功能通过 *bootstrapper image* 里的 dnsmasq 服务实现
