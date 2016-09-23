[![Build Status](https://travis-ci.org/k8sp/sextant.svg?branch=master)](https://travis-ci.org/k8sp/sextant.svg?branch=master)

# sextant
sextant 提供了可以通过PXE全自动化安装初始化一个 CoreOS + Kubernetes + Ceph 集群。

## 名词解释
| 名词        | 说明           |
| ------------- |:-------------:|
| bootstrapper        | 本程序，以docker镜像的方式运行，为初始化和安装集群提供基本服务  |
| bootstrapper server | 指运行bootstrapper的一台服务器                           |
| bsroot              | 一个目录，包含bootstrapper运行需要的配置文件，引导文件，镜像等 |

## 环境准备
bootstrapper需要运行在一台服务器上(以下称bootstrapper server)，满足以下的几个要求：

1. 待初始化的kubernetes机器需要和bootstrapper server保持网络连通
1. bootstrapper server是一台安装有docker daemon(***1.11以上版本***)的Linux服务器
1. 拥有bootstrapper server的root权限
1. 配置bootstrapper server的/etc/hosts文件，增加hostname的解析：```127.0.0.1  bootstrapper```

## 准备bsroot
***在能访问互联网的一台机器上完成下面的准备环境，配置，创建Docker镜像的步骤***
* 注：如果bootstrapper server没有互联网访问，可以事先准备好/bsroot目录然后上传到boostrapper server

获取sextant代码后，根据要初始化的整体集群规划，
编辑cloud-config-server/template/unisound-ailab/build_config.yml文件完成配置
然后下载bootstrapper用到的文件到/bsroot目录下
```shell
git clone https://github.com/k8sp/sextant.git
cd sextant/
cp cloud-config-server/template/unisound-ailab/build_config.yml cluster-desc.yml
# 根据规划集群的情况配置cluster-desc.yml
vim cluster-desc.yml
./bsroot.sh cluster-desc.yml
# 根据集群规划和bootstrapper server的网卡信息配置dnsmasq.conf
vim bsroot/config/dnsmasq.conf
# (可选)拷贝bsroot目录到bootstrapper server
scp -r bsroot IP:port:/path/to/bsroot
```

## 构建Docker镜像
在bootstrapper server或本地执行下面的命令构建bootstrapper的docker镜像：
```
docker build -t bootstrapper .
```

## 上传bsroot和bootstrapper镜像到bootstrapper server
如果上述步骤是在bootstrapper server上完成的，则可以跳过此步骤。

1. 手动打包/bsroot目录：```tar czf bsroot.tar.gz bsroot```
1. 导出编译好的docker镜像：```docker save bootstrapper > bootstrapper.tar```
1. 将bsroot.tar.gz和bootstrapper.tar上传到你的bootstrapper机器上（使用scp或ftp等工具）
1. 在bootstrapper机器上解压bsroot.tar.gz，然后加载docker镜像：```docker load < bootstrapper.tar```

## 配置bootstrapepr server的docker证书
在bootstrapper server上，将bsroot的证书拷贝到docker的配置目录下：

```
mkdir -p /etc/docker/certs.d/bootstrapper:5000
rm -rf /etc/docker/certs.d/bootstrapper:5000/*
cp bsroot/tls/ca.pem /etc/docker/certs.d/bootstrapper:5000/ca.crt
```

## 启动bootstrapper
执行下面的命令启动bootstrapper的相关组件，包括了dnsmasq, cloud-config-server, docker registry
注意通过-v指定解压的bsroot的目录挂载到容器的/bsroot
```
docker run -d --net=host \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /bsroot:/bsroot \
  bootstrapper
```
由于dnsmasq需要运行在特权模式，需要参数：--privileged

## 通过bootstrapper来初始化您的kubernetes集群
***只需要设置kubernetes节点通过PXE网络引导，并开机(和bootstrapper网络联通)，就可以自动完成安装***

## 使用集群
### 下载和配置kubectl
可以选择从以下链接下载对应的版本

* OSX
  * [官方v1.2.4](https://storage.googleapis.com/kubernetes-release/release/v1.2.4/bin/darwin/amd64/kubectl)
  * [百分点镜像v1.2.4](http://127.0.0.1/更新这个链接)
* Linux
  * [官方v1.2.4](https://storage.googleapis.com/kubernetes-release/release/v1.2.4/bin/linux/amd64/kubectl)
  * [百分点镜像v1.2.4](http://127.0.0.1/更新这个链接)

### 配置kubectl客户端
* 替换 ${MASTER_HOST} 为 cluster description 配置 YAML 文件中的 kubernetes master node hostname
* 和管理员申请分配一个你自己的帐号，并获取对应的key文件，包括ca.pem, user-key.pem和user.pem
* 替换 ${CA_CERT} 为获取到的ca.pem文件的绝对路径，如```/home/core/.kube/ca.pem```
* 替换 ${ADMIN_KEY} 为获取到的user-key.pem的路径，如```/home/core/.kube/admin-key.pem```
* 替换 ${ADMIN_CERT} 为获取到的user.pem的路径，如```/home/core/.kube/admin.pem```
* 替换 ${NAMESPACE} 为管理员分配给你的namespace（字符串）
然后执行下面的命令完成对kubectl客户端对的配置
```
$ kubectl config set-cluster default-cluster --server=https://${MASTER_HOST} --certificate-authority=${CA_CERT}
$ kubectl config set-credentials default-admin --certificate-authority=${CA_CERT} --client-key=${ADMIN_KEY} --client-certificate=${ADMIN_CERT}
$ kubectl config set-context default-system --cluster=default-cluster --user=default-admin --namespace=${NAMESPACE}
$ kubectl config use-context default-system
```

### 测试kubectl客户端可用
执行下面的命令，观察返回结果是否正常，判断是否已经完成客户端的正确配置：
```
$ kubectl get po --all-namespaces
NAMESPACE     NAME                                   READY     STATUS    RESTARTS   AGE
default       busybox                                1/1       Running   54         2d
default       kube-proxy-192.168.49.47               1/1       Running   0          18d
```

### 使用ceph集群
在集群安装完成之后，可以使用下面的命令获得admin keyring作为后续使用
```
etcdctl --endpoints http://08-00-27-ef-d2-12:2379 get /ceph-config/ceph/adminKeyring
```
比如，需要使用cephFS mount目录：
```
mount -t ceph 192.168.8.112:/ /ceph -o name=admin,secret=[your secret]
```
