# DNS
DNS using SkyDNS and etcd

目的： 通过 etcd 和 SkyDNS 实现为集群提供通用 DNS 服务, 其中 etcd 作为后端存储(key-value), 集群中的机器在开机获得IP后，把 IP 和 hostname写入 etcd， SkyDNS 通过查询 etcd 存储的 hostname 和 IP 信息提供 DNS 服务。

说明：在本例中，10.10.10.214 （简称214）作为集群外一台机器向集群中各机器提供 DNS 服务，10.10.10.201-205为以 discovery 方式运行的 etcd 5节点集群，214 以 proxy 方式启动 etcd 从集群获取 hostname/IP 信息。

# 配置

1. 通过 etcdctl 可以先看下当前集群信息

    ```
    ./etcdctl member list
    49a8e51ca7dc5ea: name=3d2326809f634b249a120b4fcbb88525 peerURLs=http://10.10.10.204:2380 clientURLs=http://10.10.10.204:2379 isLeader=false
    4325d2c4ed410428: name=04bd5c359f3a48e58f74c760a0b42419 peerURLs=http://10.10.10.203:2380 clientURLs=http://10.10.10.203:2379 isLeader=false
    6a0e53b4280500a5: name=ac5485bf26264e2eac22e938c4548b49 peerURLs=http://10.10.10.201:2380 clientURLs=http://10.10.10.201:2379 isLeader=true
    7abf47f3c7f36575: name=1a2f440953884f61846d8f1f96b80e9d peerURLs=http://10.10.10.202:2380 clientURLs=http://10.10.10.202:2379 isLeader=false
    cfdaeff1078df3b4: name=e0e2fe6de3734ed8919d18b1b24333d2 peerURLs=http://10.10.10.205:2380 clientURLs=http://10.10.10.205:2379 isLeader=false
    ```

1. 在214上启动 etcd, 以 proxy 模式

    ```
    ./etcd --proxy on  --discovery https://discovery.etcd.io/5e2d8844b9047f48d45fa70ab4a93765  --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001
    2016-07-13 20:51:29.345329 I | etcdmain: etcd Version: 2.3.6
    2016-07-13 20:51:29.345388 I | etcdmain: Git SHA: 128344c
    2016-07-13 20:51:29.345399 I | etcdmain: Go Version: go1.6.2
    2016-07-13 20:51:29.345416 I | etcdmain: Go OS/Arch: linux/amd64
    2016-07-13 20:51:29.345426 I | etcdmain: setting maximum number of CPUs to 40, total number of available CPUs is 40
    2016-07-13 20:51:29.345437 W | etcdmain: no data-dir provided, using default data-dir ./default.etcd
    2016-07-13 20:51:30.384527 I | etcdmain: proxy: using peer urls [http://10.10.10.201:2380 http://10.10.10.202:2380 http://10.10.10.203:2380 http://10.10.10.204:2380 http://10.10.10.205:2380]
    2016-07-13 20:51:30.417701 I | etcdmain: proxy: listening for client requests on http://0.0.0.0:2379
    2016-07-13 20:51:30.417959 I | proxy: endpoints found ["http://10.10.10.202:2379" "http://10.10.10.201:2379" "http://10.10.10.204:2379" "http://10.10.10.203:2379" "http://10.10.10.205:2379"]
    2016-07-13 20:51:30.418091 I | etcdmain: proxy: listening for client requests on http://0.0.0.0:4001
    ```

1. 在214上配置 SkyDNS, DNS 的监听地址 和 上游 DNS

    ```
    curl -XPUT http://127.0.0.1:4001/v2/keys/skydns/config \
   -d value='{"dns_addr":"10.10.10.214:53","ttl":3600, "nameservers": ["8.8.8.8:53","8.8.4.4:53"]}'
    ```
1. 启动 SkyDNS

   ```
   sudo ./skydns
   2016/07/13 21:02:14 skydns: metrics enabled on :/metrics
   2016/07/13 21:02:14 skydns: ready for queries on skydns.local. for tcp://10.10.10.214:53 [rcache 0]
   2016/07/13 21:02:14 skydns: ready for queries on skydns.local. for udp://10.10.10.214:53 [rcache 0]
   ```

# 验证

# 自动写入 hostname/IP 信息到 etcd

# 详细配置

# 附注
