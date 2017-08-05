# 前言
Sextant设计之初考虑的是在裸机集群中一键式的解决方案。实际使用的过程中，企业内部的集群一般都有了自己的初始化安装环境，如部署了DHCP服务器，有自己的DNS，机器也有自己的hostname，机器之间通过hostname相互也能ping同。这种情况下，同时两个DHCP服务器无疑是有冲突的，需要对Sextant做一些改动以便适应这种的环境。

我们可以把Sextant PXE服务部分设置为可选项，保留资源cache服务部分。由于post_script不能通过kick start的方式启动，所以引入fabric作为集群管理者，方便安装、配置、检查、启动、关闭软件。我们写的如下的步骤，都是在考虑了企业一般的现实情况来做的。

首先，`copy host.template.yaml host.yaml`，然后修改之。

***注意：***
- 符合要求的步骤可以略过
- 需要已经安装centos7的基础操作系统

# 步骤一：机器之间可以访问
我们需要机器都可以通过hostname来相互之间访问。如果企业的网络不支持，需要我们把静态解析写入各个节点`/etc/hosts`中(已经支持的可以忽略)。

```
# get mac_ip_host
fab -f get_mac_ip_host.py get_mac_addr

# display all before set them
fab -f set_hosts.py display

# set hosts
fab -f set_hosts.py set_mac_hosts
```

# 步骤二：生成bsroot
注意设置cluster-desc.yaml中的`start_pxe: n`。


# 步骤三：升级kernel
```
fab -f upgrade_kernel.py prepare
fab -f upgrade_kernel.py upgrade
fab -f upgrade_kernel.py reboot
```

# 步骤四：安装gpu driver
```
fab -f gpu_driver.py prepare
fab -f gpu_driver.py install
fab -f gpu_driver.py check
```

# 步骤五：安装k8s需要的软件
```
fab -f k8s.py prepare
fab -f k8s.py install
```

# TODO: 启动etcd flannel kubelet等