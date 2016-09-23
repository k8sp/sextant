## vm-cluster 自动化安装k8s
### 环境准备

| 虚拟机        | 角色       　|网络组成　|
| ------------- |-------------| ----|
| bootstrapper  | dnsmasq(dhcp,dns),cloudconfig server,boorstrapper server,registry|eth0 nat网络,eth1内部网络 ,eth2 hostonly网络|
| master        | k8s master      |eth0 内部网络|
| worker        | k8s worker     |eth0 内部网络|

注意:    
1,内部网络用于三台虚拟机之间相互通信使用    
2,vagrant的挂载需要依赖hostonly网卡

### 操作步骤

１．修改 vagrantfile 中 cluster-desc.yml.template配置,如果仅仅测试使用，保持默认即可
```
bootstrapper: 192.168.8.101
subnet: 192.168.8.0
netmask: 255.255.255.0
iplow: 192.168.8.201
iphigh: 192.168.8.220
routers: [192.168.8.101]
broadcast: 192.168.8.255
nameservers: [192.168.8.101, 8.8.8.8, 8.8.4.4]
domainname: "k8s.baifendian.com"
dockerdomain: "bootstrapper"
k8s_service_cluster_ip_range:192.168.0.0/24
k8s_cluster_dns: 192.168.0.10
hyperkube_version: "v1.3.6"
pause_version: "3.0"
flannel_version: "0.5.5"

nodes:
  - mac: "08:00:27:4a:2d:a1"
    ceph_monitor: n
    kube_master: y
    etcd_member: y

ssh_authorized_keys: |1+
    - "<SSH_KEY>"

```

２．启动bootstrapper
```
cd vm-cluster
./prepare_install_bootstrapper.sh
vagrant up bootstrapper
```
* 默认启动时会从 github 下载 bootstrapper 源码
* 执行 bsroot.sh 脚本(下载pxe镜像,生成 pxe 的配置，dns dhcp配置，registry 配置,配置 cloudconfig server 环境,下载k8s依赖镜像）

３．启动 k8s master，安装 k8s master 节点
```
cd vm-cluster
vagrant up　master
```
启动的过程成会弹出 virtualbox 窗口，在窗口中会出现如下提示：
```
Press F8 for menu.(59)
```
按 F8 后,会出现从网络安装 CoreOS 的提示如下提示：
```
Install CoreOS from network server
```
直接按 enter，然后开始从 pxe server 加载 coreos 镜像    
注意：coreos 首次仅仅是内存安装，可以通过 jounalctl -xef 查看系统日志，当提示 coreos 硬盘安装成功后系统会重启。
重启后，coreos 虚拟机会根据 cloudconfig 配置文件自动化安装k8s。可以通过在 bootstrapper　vm上ssh core@master 免密码连接 master　vm。几分钟后，可以通过docker ps查看 k8s master 是否启动成功
 
４．安装 k8s worker 节点参考 master 节点安装步骤

###troubleshooting

问题１：
```
Stderr: VBoxManage: error: Implementation of the USB 2.0 controller not found!
```
解决办法：
```
To fix this problem, install the 'Oracle VM VirtualBox Extension Pack'
```
https://www.virtualbox.org/wiki/Downloads 可以下载安装最新的VirtualBox和Extension Pack
* VirtualBox 5.1.4 for Linux hosts
* VirtualBox 5.1.4 Oracle VM VirtualBox Extension Pack

问题２：
```
Error response from daemon: client is newer than server (client API version: 1.23, server API version: 1.22)
```
解决办法：
修改 Dockerfile，添加如何参数,　指定 docker api 的版本为1.22,可以解决版本不一致的问题
```
ENV DOCKER_API_VERSION=1.22
```

问题３：    
无法找到 pxe server    
解决办法：
删除 dnsmasq.conf 中如下两行
```
 interface=eth0
 bind-interfaces
```
