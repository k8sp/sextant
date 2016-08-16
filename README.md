# auto-install

## 构建Docker镜像
执行下面的命令构建bootstrapper的docker镜像：
```
docker build -t bootstrapper:0.1 .
```
## 使用docker启动bootstrapper
执行下面的命令启动bootstrapper的相关组件，包括了dnsmasq, cloud-config-server, docker registry
```
docker run -d --net=host --privileged bootstrapper:0.1
```
由于dnsmasq需要运行在特权模式，需要参数：--privileged
