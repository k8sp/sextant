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

`说明: 此脚本不支持在 MacOS 命令行下执行`

```shell
# 进入 auto-install/k8s-install-systemd-unit/tls-tools 目录
cd auto-install/k8s-install-systemd-unit/tls-tools

# 执行生成 k8s 机群 keypair 文件的脚本, 如果目录下已存在 keypair 会提示用户是否重新生成
bash generate_tls.sh
```

![2016-07-15_14-55-43](./img/2016-07-15_14-55-43.png)

## Step2: 打包 master 和 worker 目录为 ZIP 包



