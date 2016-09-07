# Cloud-Config Template Server （CCTS）

我们的[自动安装CoreOS](https://github.com/k8sp/bare-metal-coreos)和
[自动部署Kubernetes](https://github.com/k8sp/k8s-coreos-bare-metal)的
过程需要为机群中每一台机器提供一个 cloud-config 文件。这些机器的
cloud-config 文件大同小异，所以适合写一个 template，然后带入和每台机器
（以及机群）相关的具体信息。cloud-config template server （CCTS） 是一
个 HTTP server，就是负责 template execution，并且为安装过程提供
cloud-config 文件的。

## 配置信息的更新

为了方便合作编辑，我们选择用Github来维护cloud-config模板文件
`cloud-config.template` 和配置信息文件 `build-config.yml` 。 通常我们
会把这两个文件放在一个私有 Github repo里，这样可以通过输入用户名和密码
访问，或者通过绑定一个 private SSH key 来访问。

当CoreOS安装脚本向 CCTS 请求一个特定mac地址的机器的 cloud-config 文件
的时候，CCTS 访问 Github 获取模板和配置信息，并且执行 template
execution 把配置信息带入模板， 和返回cloud-config。

具体地说，每当我们将一台新的（没有操作系统的）机器加入到机群里并且接通
电源启动机器，这台机器就会通过预先配置好的PXE server引导 CoreOS 来执行
CoreOS/Kubernetes 安装脚本。此时安装脚本向 CCTS 请求 cloud-config。此
时 CCTS 会按照新机器的mac的地址寻找其配置信息，带入模板，生成和返回
cloud-config。

也就是说，新机器启动后安装CoreOS 和 Kubernetes 的时候，会使用最新的模
板和配置信息。**而配置信息更新之后，只有重装服务器的操作系统时，才会更
新服务器上的 cloud-config**。

## 配置信息的缓存

上述过程中有一个潜在问题：如果往机群里加入新机器的时候，恰好不能访问
Github，就没法返回合理的 cloud-config 了。为此我们要在设立一个缓存，
CCTS 每隔一段时间试着访问 Github 看是否有更新，如果有，则下载下来并且
替换缓存中的内容。

最简答的缓存机制是 CCTS 在内存中维护，但是如果CCTS 被重启，则缓存信息
就丢失了。目前的做法是，将这些配置信息写入本地文件。

## 相关算法

1. 处理 HTTP request 的伪代码如下

```
func HttpHandler(mac_addr) cloud_config {
  template, config, timeout := RetriveFromGithub(timeout = 1s)
  if !timeout {
    WriteToFile(template, config)
  } else {
    template, config, ok := ReadFromFile()
    if !ok {
	  return error
    }
  }
  return Execute(template, config[mac])
}
```

2. 周期性访问Github并缓存信息至etcd的伪代码如下

```
go func() {
  for {
    Sleep(10m)
    template, config := RetriveFromGithub(timeout = infinite)
	WriteToFile(template, config)
  }
}
```

## Go环境配置

```
cd ~
wget https://storage.googleapis.com/golang/go1.6.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.6.3.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
export GOPATH=<GoPathDir>
```

## 获取并编译Go代码

下面的命令中需要使用到[Github personal access token](https://github.com/k8sp/sextant/issues/29)，请根据[这篇文档](https://github.com/k8sp/sextant/issues/29)事先生成。

```
git config --global url."https://<GitHubPersonalAccessToken>:x-oauth-basic@github.com/".insteadOf "https://github.com/" 
go get github.com/k8sp/sextant/cloud-config-server

```

## 配置为系统服务(system unit file)

```
sudo vim /etc/systemd/system/cloud-config.service 
```

**cloud-config.service 内容如下:**

```
[Unit]
Description=Cloud config server
After=network.target
Wants=network-online.target

[Service]
User=root
Group=root
ExecStart=/work/golang/bin/cloud-config-server
RestartSec=5s
Restart=always

[Install]
WantedBy=multi-user.target
```
**设置开机启动,并启动服务**
```
sudo systemctl enable cloud-config.service; sudo systemctl start cloud-config.service;
```

(END)
