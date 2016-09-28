# Sextant

Sextant是一套软件系统，简化Kubernetes机群的自动部署。Sextant之于Kubernetes类似RedHat之于Linux。

## 设计思路

为了让机群中的机器可以全自动地安装CoreOS和Kubernetes，并且加入Kubernete机群，我们需要将机群中一台有static IP的机器上运行PXE服务（DHCP+TFTP）。这台机器我们称为bootstrapper server。我们希望顺便利用这台bootstrapper server做机群中机器的IP和域名映射管理，所以需要DNS服务。以上都可以通过运行dnsmasq软件实现。此外，还需要运行我们自己开发的cloud-config-server来为机群中各个CoreOS服务器提供定制化的cloud-config文件，以及其他需要通过HTTP协议提供给机群的信息，包括CoreOS的安装镜像。

为了方便地部署上述服务，我们将其封装在一个Docker image里，称为*bootstrapper image*。这个image在执行的时候，会挂载bootstrapper server上本地文件系统里的一个目录，里面有上述各服务的配置文件，以及它们需要依赖的其他文件。为了方便，我们称这个目录为`bsroot`目录。

为了生成bsroot目录，我们要运行bsroot.sh。这个脚本读取一个机群描述文件 `cluster-desc.yml`，分析其中信息，生成配置文件。

因为bsroot目录里的很多文件需要预先下载，而下载需要翻墙，所以我们假设bsroot.sh是在一台“笔记本电脑”上执行的，这样我们可以抱着这台笔记本跑去“网吧”翻墙上网。随后，我们回到公司，把笔记本上生成的bsroot目录需要被拷贝到 bootstrapper server上，并且启动bootstrapper container。

实际上，Sextant提供一个regeression test方案，我们称为 vm-cluster。这个方案利用Vagrant创建若干台虚拟机，包括bootstrapper VM和Kubernetes机群里的服务器。在这个方案里，host（开发机）就对应上述的“笔记本”了。

## 环境需求

1. “笔记本”

   1. bash：用于执行 bsroot.sh
   1. Go：用于编译Sextant
   1. git：被 go get 命令调用获取Sextant及其依赖
   1. docker：用于docker pull各种Kubernetes机群需要的images，比如pause。
   1. wget：用于下载各种文件
   1. ssh/scp：
   
1. bootstrapper server

   1. 静态IP：dnsmasq运行PXE 和 DNS service的时候需要
   1. docker：执行 bootstrapper docker container
   1. root权限：bootstrapper container需要以特权模式运行，比如运行docker container
   1. 计划要自动安装CoreOS和kubernetes的机群机器要和bootstrapper所在的机器网络连通（2层连通）。

## 使用方法


1. 在*笔记本*或者vm-cluster的*host*上的准备工作流程如下：
   
   1. 配置 Go 环境

      ```
      mkdir -p ~/work
      export GOPATH=$HOME/work
      ```

   1. 获取Sextant并且获取其中Go程序的依赖

      ```
      go get https://github.com/k8sp/sextant/...
      ```

      请注意上面命令里的省略号不可以少。

   1. 编辑 `~/cluster-desc.yml` 描述即将安装的机群

   1. 下载相关文件，生成 `./bsroot` 目录

      ```
      $GOPATH/src/github.com/k8sp/sextant/bsroot.sh ~/cluster-desc.yml
      ```

   1. 把准备好的内容上传到 bootstrapper server（或者bootstrapper VM）：

      ```
      scp -r ./bsroot root@bootstrapper:/
      ```

1. 在 bootstrapper server（或者bootstrapper VM）上执行 [`start_bootstrapper_container.sh`](https://github.com/k8sp/sextant/blob/master/start_bootstrapper_container.sh)：

   ```
   host $ ssh bootstrapper
   bootstrapper $ sudo /root/start_bootstrapper_container.sh
   ```

   或者

   ```
   host $ ssh root@bootstrapper -c "nohup /root/start_bootstrapper_container.sh"
   ```

   `start_bootstrapper_container.sh` 会：

   1. 启动 bootstrapper service：

      ```
      host $ ssh bootstrapper
      bootstrapper $ docker load /bsroot/bootstrapper.tar
      bootstrapper $ docker run -d bootstrapper
      ```

   1. 为了让bootstrapper service中的Docker registry service能向
      Kubernetes机群提供服务，还需要向其中push一些必须的images。这些
      images都事先由 bsroot.sh下载好，并且放进bsroot目录里了。
 

## 设计细节

1. 规划机群，并且把规划描述成[ClusterDesc配置文件](https://raw.githubusercontent.com/k8sp/sextant/master/cloud-config-server/template/unisound-ailab/build_config.yml)，比如如哪个机器作为master，哪些机器作为etcd机群，哪些作为worker。每台机器通过MAC地址唯一标识。

1. 管理员在一台预先规划好的的机器上，下载／上传bootstrapper的docker image，并通过docker run启动bootstrapper。启动成功后，bootstrapper会提供DHCP, DNS(服务于物理节点), PXE, tftp, cloud-config HTTP服务, CoreOS镜像自动更新服务。

1. 将机群中的其他所有节点开机，并从网络引导安装。即可完成整个机群的初始化。

1. 每启动一台新的机器（网络引导），先从DHCP获取一个IP地址，DHCP server将启动引导指向PXE server，然后由PXE server提供启动镜像（保存在tftpserver），至此，新的机器可以完成内存中的CoreOS引导，为CoreOS操作系统安装提供环境。

1. 由于PXE server配置了initrd参数，指定了install.sh的cloud-config文件（网络引导cloud-config），PXE引导启动后，将使用HTTP访问cloud-config-server，获得到这个install.sh。install.sh执行coreos-install命令，把CoreOS系统安装到当前机器并reboot。安装命令coreos-install 也可以指定一个cloud-config文件(系统安装cloud-config)，这个文件是cloud-config-server自动生成生成的，这个cloud-config文件将本机安装成为对应的kubernetes机群节点（由之前的ClusterDesc指定的角色）。
 
1. 机器重启后，由于已经安装了系统，磁盘上有MBR，则使用磁盘引导。磁盘上的CoreOS启动后，会根据之前coreos-install指定的cloud-config文件完成配置，此时kubernetes的相关组件也完成了启动并把本机的hostname汇报给kubernetes master(hostname用mac地址生成)。

1. 网络配置统一都使用了DHCP，由dnsmasq统一管理和分配。在IP地址租期之内，DHCP会分配给本机一个相对稳定的IP地址。如果超过了租期，物理节点就会获得一个不同的IP，但由于kubernetes worker是根据mac地址生成的hostname上报给master的，之前给这个node打的标签也不会丢失。***所以在配置的时候需要着重考虑租期的配置***

1. 机群里所有服务器的CoreOS更新都是通过访问 bootstrapper 上 cloud-config-server 提供的镜像来做的。不需要访问外网。因此，如果我们希望机群更新，则需要手工从外网下载新版本CoreOS镜像，并且上传到 bootstrapper server 上的 bsroot 目录里。


## 组件功能

### dnsmasq

dnsmasq在机群中提供DHCP, DNS(物理机的DNS), PXE服务。使用docker启动dnsmasq的试验方法可以参考：https://github.com/k8sp/sextant/issues/102

### cloud-config-server

cloud-config-server是使用Go语言开发的一个HTTP Server，将提供安装kubernetes组件用到的需要通过HTTP访问的所有资源。包括：

* install.sh, 访问url如: http://bootstrapper/install.sh
* CoreOS镜像, 访问url如: http://bootstrapper/stable/1010.5.0/coreos_production_image.bin.bz2
* 根据模版自动生成的cloud-config文件, 访问url如: http://bootstrapper/cloud-config/08:00:36:a7:5e:9f.yaml
* 自动生成的证书, ca.pem以及为api-server, worker, client生成的证书

### docker registry

在bootstrapper所在的机器上，启动一个docker registry，这样在kubernetes master/worker启动时需要的docker镜像（hyperkube, kubelet, pause, skydns, kube2sky等）就可以不需要翻墙即可完成启动。这样的好处是：

1. 在内网可以获得最快的镜像下载和启动速度，即使翻墙，下载镜像的速度也会很慢。
1. 不需要额外搭建翻墙环境

这样，bootstrapper在编译的时候就需要下载好docker registry的镜像，kubernetes需要的镜像。启动bootstrapper的时候，先把docker registry的镜像load到docker daemon中，然后再把kubernetes用到的镜像push到启动好的registry中，并打上对应的tag（cloud-config-server生成的cloud-config文件使用的镜像的tag）
