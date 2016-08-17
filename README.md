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
docker build -t bootstrapper .
```
## 使用docker启动bootstrapper
编写/etc/dnsmasq.conf：
```
# dnsmasq使用的网卡
interface=eth0
# 只使用绑定的网卡收发消息，比如在另一个网卡也要提供DNS的时候
bind-interfaces
# A SRV record sending LDAP for the example.com domain to
# ldapserver.example.com port 289 (using domain=)
domain=k8s.baifendian.com
user=root
# 启用DHCP服务，配置DHCP为客户机分配的IP段，掩码，租期
dhcp-range=192.168.8.102,192.168.8.200,255.255.255.0,12h
# 输出详细的DHCP服务日志
log-dhcp

# 配置BOOTP的文件名，并使用dnsmasq内部的tftp服务器（参考下面的配置）提供PXE服务
dhcp-boot=pxelinux.0

# 配置DHCP服务发送的Gateway地址
dhcp-option=3,192.168.8.101

# 配置DHCP服务发送的DNS地址
dhcp-option=6,192.168.8.101,8.8.8.8

# 禁止dnsmasq读取/etc/hosts
no-hosts

# 配合domain配置项使用，将域名写入hosts文件
expand-hosts
# 禁止dnsmasq读取/etc/resolv.conf来设置DNS
no-resolv

# 增加本地域名，这些域名下的请求将直接从/etc/hosts或DHCP响应
local=/k8s.baifendian.com/
# Never forward plain names (without a dot or domain part)
# 不转发非域名的请求到公网（不包含.或一级域名的）
domain-needed


# 配置DHCP的广播地址
dhcp-option=28,192.168.8.255

# 是否启用NTP Server
#dhcp-option=42,0.0.0.0
# PXE和tftp的相关配置
pxe-prompt="Press F8 for menu.", 60
pxe-service=x86PC, "Install CoreOS from network server 192.168.50.4", pxelinux
enable-tftp
tftp-root=/var/lib/tftpboot
```
执行下面的命令启动bootstrapper的相关组件，包括了dnsmasq, cloud-config-server, docker registry
```
docker run -d --net=host \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/dnsmasq.conf:/etc/dnsmasq.conf \
  -v /var/lib/tftpboot:/var/lib/tftpboot \
  bootstrapper
```
由于dnsmasq需要运行在特权模式，需要参数：--privileged
