# auto-install

## 准备bootstrapper运行环境
执行以下命令获取auto-install代码并下载bootstrapper用到的文件到/bsroot目录下：
```
git clone https://github.com/k8sp/auto-install.git
cd auto-install
./bsroot.sh
```
* 注：如果bootstrapper机器没有互联网访问，可以事先准备好/bsroot目录然后上传到boostrapper机器

## 配置
根据实际环境配置下面的文件：
```
/bsroot/config/dnsmasq.conf
/bsroot/config/registry.yml
/bsroot/config/cluster-desc.yml
```

## 构建Docker镜像
在bootstrapper或本地执行下面的命令构建bootstrapper的docker镜像：
```
docker build -t bootstrapper .
```
## 使用docker启动bootstrapper
执行下面的命令启动bootstrapper的相关组件，包括了dnsmasq, cloud-config-server, docker registry
```
docker run -d --net=host \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /bsroot:/bsroot \
  -v /var/lib/tftpboot:/var/lib/tftpboot \
  bootstrapper
```
由于dnsmasq需要运行在特权模式，需要参数：--privileged

## 通过bootstrapper来初始化您的kubernetes集群
***只需要设置kubernetes节点通过PXE网络引导，并开机(和bootstrapper网络联通)，就可以自动完成安装***
