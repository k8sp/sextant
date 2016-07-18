# 基于Vagrant的CoreOS集群部署Kubernetes

通过Vagrant在三台CoreOS虚拟机节点上部署Kubernetes集群，一台master，两台worker

## Kubernetes简介

[Kubernetes](http://kubernetes.io)是一个开源的系统，用于自动部署，弹性扩容以及管理容器化的应用，是[Docker](https://www.docker.com/)生态圈中重要一员。Kubernetes来源于Google的[Borg系统](https://research.google.com/pubs/pub43438.html)，经过了十多年的实践经验已经被证实是可以用于大数据量、高并发的实际生产环境中。其主要功能包括：

1. 使用Docker对应用程序包装(package)、实例化(instantiate)、运行(run)。
2. 以集群的方式运行、管理跨机器的容器。
3. 解决Docker跨机器容器之间的通讯问题。
4. Kubernetes的自我修复机制使得容器集群总是运行在用户期望的状态。

## 准备３台CoreOS虚拟机
```
git clone https://github.com/coreos/coreos-vagrant.git
cd coreos-vagrant
cp config.rb.sample config.rb
cp user-data.sample user-data
```
修改config.rb中配置，修改虚拟机实例数和内存大小
```
$num_instances=3
$vm_memory = 4096
```

然后启动该虚拟机

	vagrant up
	
## 部署Kubernetes

在已经建立的三台coreos机器集群安装并配置Kubernetes，其中1个结点作为master（172.17.8.101 core-01），并不参与schedule的任务调度，另外2个结点作为worker(172.17.8.102 core02, 172.17.8.103 core-03)，来创建并运行Pod。


### 配置master结点
首先进入主结点，在本例中，以core-01机器为主结点。前提是etcd集群能正常工作。因为在user-data文件中已经修改过discovery的token，所以默认情况下已经启动了3结点的etcd集群，可使用如下命令查看etcd集群各结点：

	$ etcdctl member list

待确认etcd服务正常后，为core用户修改密码，目的是方便与client机器进行数据传输（使用`scp`命令拷贝文件）。

	$ vagrant ssh core-01

配置`/etc/hosts`在集群之间方便通信
```
 172.17.8.101 core-01
 172.17.8.102 core-02
 172.17.8.103 core-03
```	
进入虚拟机后运行新建一个目录，运行`kubernetes-generate-cas.sh`用OpenSSL生成Kubernetes运行安装所需要的[认证证书](https://coreos.com/kubernetes/docs/latest/openssl.html)，如
```
$ cd ~/kube-ca
$ sh kubernetes-generate-cas.sh
```
将`ca.pem`，`apiserver.pem`，`apiserver-key.pem`上传至用户目录，在该目录下运行`kubernetes-master-deploy.sh`

```
$ sudo sh kubernetes-master-deploy.sh
```

等待后台进程下载，过程可能会需要几分钟到几个小时，然后确认`apiserver`进程是否启动
```
$ curl http://127.0.0.1:8080/version
```

如果成功会返回如下形式的响应：
```
{
  "major": "1",
  "minor": "1",
  "gitVersion": "v1.1.7_coreos.2",
  "gitCommit": "388061f00f0d9e4d641f9ed4971c775e1654579d",
  "gitTreeState": "clean"
}
```
现在我们可以创建`kube-system`命令空间：

	$ curl -H "Content-Type: application/json" -XPOST -d'{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"kube-system"}}' "http://127.0.0.1:8080/api/v1/namespaces"

### 配置worker结点

首先进入每个worker结点

	$ vagrant ssh core-02 

配置/etc/hosts在集群之间方便通信

	172.17.8.101 core-01
	172.17.8.102 core-02
	172.17.8.103 core-03

将`ca.pem`，`${WORKER_FQDN}-worker.pem`，`${WORKER_FQDN}-worker-key.pem`上传至用户目录，**修改**并运行`kubernetes-worker-deploy.sh`。其中，`${WORKER_FQDN}`是该worker结点在集群中唯一的名称，在本例中`172.17.8.102`为`kube-worker-1`，`172.17.8.103`为`kube-worker-2`。

修改`${WORKER_FQDN}`以及`${ADVERTISE_IP}`，分别为结点在Kubernetes集群中的唯一名称和其对应的可访问的IP地址。

	$ sudo sh kubernetes-worker-deploy.sh

### 配置kubectl并验证

下载`kubectl`，授权并加入到`path`路径中。

	$ curl -O https://storage.googleapis.com/kubernetes-release/release/v1.2.4/bin/linux/amd64/kubectl
	$ chmod +x kubectl
	$ mv kubectl /usr/local/bin/kubectl

用下列命令配置kubectl以连接目标集群，根据说明替换其中关键变量：

替换`${MASTER_HOST}`为主结点的IP地址或者Host名称。

	$ kubectl config set-cluster default-cluster --server=https://${MASTER_HOST} --certificate-authority=ca.pem
	$ kubectl config set-credentials default-admin --certificate-authority=ca.pem --client-key=admin-key.pem --client-certificate=admin.pem
	$ kubectl config set-context default-system --cluster=default-cluster --user=default-admin
	$ kubectl config use-context default-system

在client机器上键入命令，可以查看Kubernetes结点状态

	$ kubectl get nodes

## 附录

### 调试技巧

可以在CoreOS系统中使用`journalctl`命令查看日志，根据日志的提示与报错再针对性搜索相关解决方案，该命令一般常用选项有：

	$ journalctl -xe

从未行开始浏览日志，`f`向前翻页，`b`向后翻页，`q`键退出。

	$ journalctl -u docker.service

查看特定单元(`unit`)，如`docker.service`产生的日志。

	$ journalctl -f

跟踪日志，按`ctrl` + `c`键退出。

### 翻墙问题
由于被墙的原因，导致无法下载gci.io，qury.io上的镜像，解决方法是：可以通过docker.io上下载所需镜像，然后通过docker tag重命名.详细内容可以参考`kubernetes-master-deploy.sh` 和 `kubernetes-worker-deploy.sh`脚本.

### 参考：
[CoreOS + Kubernetes Step By Step](https://coreos.com/kubernetes/docs/latest/getting-started.html)

