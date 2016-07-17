# auto-install/k8s-install-systemd-unit

## 项目介绍

通过 cloud-config 以服务启动的方式来安装 k8s, 服务执行命令通过下载 master/worker zip包, 执行安装脚本, 来实现系统自动化安装 k8s 流程.

## 使用说明

### Step1 生成 k8s 机群 keypair 文件

修改 environment 文件中 `KUBERNETES_MASTER_IPV4` 地址为机群 master 节点 IP

```shell
vim environment
------
KUBERNETES_MASTER_IPV4=10.10.10.209
```

进入 auto-install/k8s-install-systemd-unit/tls-tools, 执行 generate_tls.sh. 脚本会生成机群 keypair, 拷贝environment 配置到 worker、kubectl 目录, 拷贝对应的 keypair 到 master、worker、kubectl 目录.

__说明: 此脚本不支持在 MacOS 命令行下执行__

```shell
# 进入 auto-install/k8s-install-systemd-unit/tls-tools 目录
cd auto-install/k8s-install-systemd-unit/tls-tools

# 执行生成 k8s 机群 keypair 文件的脚本, 如果目录下已存在 keypair 会提示用户是否重新生成
bash generate_tls.sh
```

![2016-07-15_14-55-43](./img/2016-07-15_14-55-43.png)

## Step2: 打包 master、worker、kubectl 目录

```shell
# 确保在 auto-install/k8s-install-systemd-unit/ 目录下
pwd
auto-install/k8s-install-systemd-unit/
# 打包目录
zip master.zip master/*
zip worker.zip worker/*
zip kubectl.zip kubectl/*
# 上传到自己 HTTP 文件服务器
scp *.zip 192:/usr/share/nginx/http/install-k8s
```

## Step3: 配置 cloud-config 

要把安装 k8s 的流程集成到cloud-config 中, cloud-config 分为 master/work 两个角色, 配置块为[cloud-config.yml](./cloud-config.yml)

## Step4: 配置本地 kubectl

下载HTTP服务端的`kubectl.zip`, 配置 kubectl

```shell
# 下载 kubectl.zip 并解压
wget -O kubectl.zip http://10.10.10.192/install-k8s/kubectl.zip && unzip -o kubectl.zip
# 执行 kube.sh, 根据提示执行相应操作
bash kube.sh
# 验证机群连接
kubectl get node
kubectl get pod --namespace=kube-system
```



