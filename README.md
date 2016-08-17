# auto-install

## 获取k8s所需要的镜像
执行以下命令获取镜像并save为tar的格式：
```
docker pull typhoon1986/hyperkube-amd64:v1.2.0
docker pull typhoon1986/pause:2.0
docker save typhoon1986/pause:2.0 > pause:2.0.tar
docker save typhoon1986/hyperkube-amd64:v1.2.0 > hyperkube-amd64:v1.2.0.tar
```
## 构建Docker镜像
执行下面的命令构建bootstrapper的docker镜像：
```
docker build -t bootstrapper:0.1 .
```
## 使用docker启动bootstrapper
执行下面的命令启动bootstrapper的相关组件，包括了dnsmasq, cloud-config-server, docker registry
```
docker run -d --net=host -v /var/run/docker.sock:/var/run/docker.sock --privileged bootstrapper:0.1
```
由于dnsmasq需要运行在特权模式，需要参数：--privileged
