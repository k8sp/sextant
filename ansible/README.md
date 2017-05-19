# ansible 目标

* 在已安装操作系统的集群上二次部署。
* 实现 PXE 安装和集群部署分离。
* 重构 sextant 的目录和架构，实现资源准备，PXE安装和集群部署分离。

# ansible 任务分解

* 安装 package。
* 重构 post-process.sh。
* 重构 GPU 安装。
* 重构 cloud-init 。

# ansible 安装与使用

* 从源码安装

```bash
$ git clone git://github.com/ansible/ansible.git --recursive
$ cd ./ansible
```

   使用前需要:

```bash
$ source ./hacking/env-setup
```

* ssh-agent

确保你的 public SSH key 必须在集群系统的 *authorized_keys* 中。

使用SSH Key来授权，为了避免在建立SSH连接时，重复输入密码你可以这么做:

```bash
$ ssh-agent bash
$ ssh-add ~/.ssh/id_rsa
```

* 运行 

```bash
$ cd /work/go-work/src/github.com/k8sp/sextant/ansible
$ ./run.sh check 
$ ./run.sh run
```

# ansible 架构

```bash
.
├── makefile
├── production  # 生产环境配置，功能结构同 staging 。
│   ├── group_vars
│   ├── hosts
│   └── host_vars
├── README.md   
├── roles       # Roles
│   ├── centos  # post all common role
│   │   ├── defaults
│   │   ├── files
│   │   │   ├── authorized_keys
│   │   │   ├── docker.service
│   │   │   └── settimezone.service
│   │   ├── handlers
│   │   │   └── main.yml
│   │   ├── meta
│   │   ├── tasks
│   │   │   └── main.yml
│   │   ├── templates
│   │   │   ├── etcd.j2
│   │   │   ├── flanneld.j2
│   │   │   └── setup-network-enviroment.j2
│   │   └── vars
│   │       └── tls_setttings
│   ├── common  # pre start common role
│   │   ├── defaults
│   │   ├── files
│   │   │   └── tls           # this ca is copy from /bsroot/tls
│   │   │       ├── ca-key.pem   
│   │   │       └── ca.pem       
│   │   ├── handlers
│   │   │   └── main.yml
│   │   ├── meta
│   │   ├── tasks
│   │   │   └── main.yml
│   │   ├── templates
│   │   │   └── hosts.j2
│   │   └── vars
│   │       └── tls_setttings
│   ├── master   # master role
│   │   ├── defaults
│   │   ├── files
│   │   │   ├── abac
│   │   │   │   └── policy.jsonl
│   │   │   ├── basic
│   │   │   │   └── basic_auth.csv
│   │   │   ├── config
│   │   │   │   └── local-kubeconfig.yaml
│   │   ├── handlers
│   │   │   └── main.yml
│   │   ├── meta
│   │   ├── tasks
│   │   │   └── main.yml
│   │   ├── templates
│   │   │   ├── addons-manager-kubeconfig.j2
│   │   │   ├── kube-addons-service.j2
│   │   │   ├── kubelet-master-service.j2
│   │   │   ├── kubernetes-master-manifest.j2
│   │   │   └── master-kubelet-kubeconfig.j2
│   │   └── vars
│   │       └── tls_setttings
│   └── worker       # woker role
│       ├── defaults
│       ├── files
│       ├── handlers
│       │   └── main.yml
│       ├── meta
│       ├── tasks
│       │   └── main.yml
│       ├── templates
│       │   ├── kube-proxy-manifest.j2
│       │   ├── openssl-conf.j2
│       │   ├── worker-kubeconfig.j2
│       │   └── worker-kubelet-service.j2
│       └── vars
│           └── tls_setttings
├── run.sh          # candy shell
├── site.yml        # playbook
└── staging         # 测试环境集群配置
    ├── group_vars  # group vars
    │   └── all
    ├── hosts       # 集群 hostname
    └── host_vars   # host vars
        ├── 00-25-90-c0-f7-88
        ├── 00-25-90-c0-f7-c8
        ├── 00-e0-81-ee-82-5b
        ├── 0c-c4-7a-15-e1-9c
        └── 0c-c4-7a-e5-59-40
```

# 状态

* 在已安装 OS 的集群上自动部署 kubernetes 。 
* 集群支持 TLS 。
* 只测试了单节点 etcd 集群部署。


# 注意

* 集群的 CA `ca.pem` 和 key `ca-key.pem` 放在 `ansible/roles/common/files/tls` 中。 其他需要的证书在 `ansible/roles/[master|woker]/task/main.yaml` 中生成。


# 参考

* [Ansible 中文权威指南](http://ansible-tran.readthedocs.io/en/latest/)
* [Ansible Docs](http://docs.ansible.com/ansible/list_of_all_modules.html)
* [etcd configuration flags](https://github.com/coreos/etcd/blob/master/Documentation/op-guide/configuration.md)
* [flannel configuration](https://github.com/coreos/flannel/blob/master/Documentation/configuration.md)
* [Docker register](https://github.com/docker/docker.github.io/blob/master/registry/index.md)
* [docker register deployment instructions](https://github.com/docker/docker.github.io/blob/master/registry/deploying.md)
* [Configuring a DHCP Client](https://www.centos.org/docs/5/html/Deployment_Guide-en-US/s1-dhcp-configuring-client.html)
* [Using environment variables in systemd units](https://coreos.com/os/docs/latest/using-environment-variables-in-systemd-units.html)
* [systemd.unit — Unit configuration](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)


