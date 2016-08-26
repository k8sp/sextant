# auto-install
auto-install 提供了可以通过PXE快速安装初始化一个kubernetes集群的bootstrapper服务。

## 环境准备
bootstrapper需要运行在一台服务器上(以下称bootstrapper server)，满足以下的几个要求：
1. 待初始化的kubernetes机器需要和bootstrapper server保持网络连通
1. bootstrapper server是一台安装有docker daemon(1.11以上版本)的Linux服务器
1. 拥有bootstrapper server的root权限

## 初始化配置和准备bootstrapper需要的镜像文件
***在能访问互联网的一台机器上完成下面的准备环境，配置，创建Docker镜像的步骤***
获取auto-install代码后，根据要初始化的整体集群规划，
编辑cloud-config-server/template/unisound-ailab/build_config.yml文件完成配置
然后下载bootstrapper用到的文件到/bsroot目录下
```
git clone https://github.com/k8sp/auto-install.git
vim cloud-config-server/template/unisound-ailab/build_config.yml
cd auto-install
./bsroot.sh
```
* 注：如果bootstrapper机器没有互联网访问，可以事先准备好/bsroot目录然后上传到boostrapper server

## 配置
根据实际环境配置下面的文件：
```
/bsroot/config/dnsmasq.conf
/bsroot/config/registry.yml
```
创建跟证书：
```
cd /bsroot/tls
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=kube-ca"
```

## 构建Docker镜像
在bootstrapper或本地执行下面的命令构建bootstrapper的docker镜像：
```
docker build -t bootstrapper .
```

## 上传到集群内部的bootstrapper机器
如果上述步骤是在bootstrapper服务器上完成的，则可以跳过此步骤。
1. 手动打包/bsroot目录：```tar czf bsroot.tar.gz /bsroot```
1. 导出编译好的docker镜像：```docker save bootstrapper > bootstrapper.tar```
1. 将bsroot.tar.gz和bootstrapper.tar上传到你的bootstrapper机器上（使用scp或ftp等工具）
1. 在bootstrapper机器上解压bsroot.tar.gz到/目录，然后加载docker镜像：```docker load < bootstrapper.tar```

## 使用docker启动bootstrapper
执行下面的命令启动bootstrapper的相关组件，包括了dnsmasq, cloud-config-server, docker registry
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
