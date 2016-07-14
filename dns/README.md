# DNS
DNS using SkyDNS and etcd

目的： 通过 etcd 和 SkyDNS 实现为集群提供通用 DNS 服务, 其中 etcd 作为后端存储(key-value) hostname/IP 信息, 集群中的机器在开机获得IP后，把 hostname/IP 信息写入 etcd， SkyDNS 通过查询 etcd 存储的 hostname/IP 信息提供 DNS 服务。

说明：在本例中，10.10.10.214 （简称214）作为集群外一台机器向集群中各机器提供 DNS 服务，10.10.10.201-205为以 discovery 方式运行的 etcd 5节点集群。


方案 ：214 的 SkyDNS 直接从集群的 etcd 获取 hostname/IP 信息。

在集群中任意一台机器执行 etcdctl 可以先看下当前集群信息，在214上可以加上 --endpoints 指定集群信息（./etcdctl  --endpoints=http://10.10.10.201:2379 member list），集群内机器可以无需指定，使用默认endpoints。

```
./etcdctl member list
49a8e51ca7dc5ea: name=3d2326809f634b249a120b4fcbb88525 peerURLs=http://10.10.10.204:2380 clientURLs=http://10.10.10.204:2379 isLeader=false
4325d2c4ed410428: name=04bd5c359f3a48e58f74c760a0b42419 peerURLs=http://10.10.10.203:2380 clientURLs=http://10.10.10.203:2379 isLeader=false
6a0e53b4280500a5: name=ac5485bf26264e2eac22e938c4548b49 peerURLs=http://10.10.10.201:2380 clientURLs=http://10.10.10.201:2379 isLeader=true
7abf47f3c7f36575: name=1a2f440953884f61846d8f1f96b80e9d peerURLs=http://10.10.10.202:2380 clientURLs=http://10.10.10.202:2379 isLeader=false
cfdaeff1078df3b4: name=e0e2fe6de3734ed8919d18b1b24333d2 peerURLs=http://10.10.10.205:2380 clientURLs=http://10.10.10.205:2379 isLeader=false
```

## 配置

1. 配置 SkyDNS, DNS 的监听地址 和 上游 DNS

    ```
    curl -XPUT http://10.10.10.201:2379/v2/keys/skydns/config  -d value='{"dns_addr":"10.10.10.214:53","ttl":3600, "nameservers": ["8.8.8.8:53","8.8.4.4:53","domain":"unisound.com"]}'
    ```

    或者通过etcdctl命令

    ```
    ./etcdctl --endpoints=http://10.10.10.201:2379 set /skydns/config '{"dns_addr":"10.10.10.214:53","ttl":3600, "nameservers":["8.8.8.8:53", "8.8.4.4:53","domain":"unisound.com"]}'
    ```

   curl 命令和 etcdctl 都可以传递json参数，下面仅用etcdctl 命令举例。

   skydns默认的域名域是 skydns.local. 通过domain参数用户可以指定自己的域名域，比如 unisound.com。


1. 在 214 启动 SkyDNS

   ```
   sudo ./skydns  -machines="http://10.10.10.201:2379"
   2016/07/15 00:07:44 skydns: metrics enabled on :/metrics
   2016/07/15 00:07:44 skydns: ready for queries on unisound.com. for tcp://10.10.10.214:53 [rcache 0]
   2016/07/15 00:07:44 skydns: ready for queries on unisound.com. for udp://10.10.10.214:53 [rcache 0]
   ```


## 解析验证

1. 在集群中一台机器 10.10.10.201 执行把 IP/hostname 信息写入 etcd, hostname 为 machine1.ailab.unisound.com, IP 为 10.10.10.201。

    ```
    core@zodiac-01 ~ $ etcdctl set skydns/com/unisound/ailab/machine1 '{"host":"10.10.10.201"}'
    {"host":"10.10.10.201"}
    ```

    在上述命令参数中 skydns/com/unisound/ailab/machine1，以 / 分割字符串，其中第一个 skydns 代表前缀，后面的 com/unisound/ailab/machine1 是和 hostname 倒序对应，并以 / 代替 hostname 中的 . 分隔符。
1. 在其他机器上，做域名查询验证

    ```
    core@zodiac-04 ~ $ dig @10.10.10.214 machine1.ailab.unisound.com +short
    10.10.10.201
    ```

1. 查询外网域名

    ```
    core@zodiac-04 ~ $ dig @10.10.10.214 www.baidu.com +short
    www.a.shifen.com.
    61.135.169.125
    61.135.169.121
    ```

1. ping 测试，暂时手工改 /etc/resolv.conf 中的 nameserver 验证（等 DHCP 自动分配DNS Server 完成再重新测试）

    ```
    zodiac-04 core # cat /etc/resolv.conf
    nameserver 10.10.10.214
    zodiac-04 core # ping machine1.ailab.unisound.com
    PING machine1.ailab.unisound.com (10.10.10.201) 56(84) bytes of data.
    64 bytes from 10.10.10.201: icmp_seq=1 ttl=64 time=0.139 ms
    64 bytes from 10.10.10.201: icmp_seq=2 ttl=64 time=0.161 ms
    64 bytes from 10.10.10.201: icmp_seq=3 ttl=64 time=0.219 ms
    ^C
    --- machine1.ailab.unisound.com ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2003ms
    rtt min/avg/max/mdev = 0.139/0.173/0.219/0.033 ms
    zodiac-04 core # ping www.baidu.com
    PING www.a.shifen.com (61.135.169.125) 56(84) bytes of data.
    64 bytes from 61.135.169.125: icmp_seq=1 ttl=51 time=2.01 ms
    64 bytes from 61.135.169.125: icmp_seq=2 ttl=51 time=1.84 ms
    64 bytes from 61.135.169.125: icmp_seq=3 ttl=51 time=1.95 ms
    ^C
    --- www.a.shifen.com ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2002ms
    rtt min/avg/max/mdev = 1.845/1.938/2.019/0.087 ms
    ```



## 自动写 hostname/IP 信息到 etcd

1. 在 cloud-config 创建 sendhostname service 用于开机启动时，自动将 hostname/IP 信息写入 etcd，其中，%H 代表 hostname, $public_ipv4 代表 public ipv4。

    ```
    - name: "sendhostname.service"
          command: start
          content: |
            [Unit]
            Description=Send hostname and IP to etcd2
            Requires=etcd2.service
            After=etcd2.service

            [Service]
            ExecStart=/usr/bin/etcdctl set skydns/com/unisound/ailab/%H '{"host":"$public_ipv4"}'
            Type=oneshot
    ```

1. 执行  coreos-cloudinit  --from-file /var/lib/coreos-install/user_data 使配置生效

1. 可以查看 sendhostname service 状态

    ```
    zodiac-03 coreos-install # systemctl status sendhostname
    ● sendhostname.service - Send hostname and IP to etcd2
   Loaded: loaded (/etc/systemd/system/sendhostname.service; static; vendor preset: disabled)
   Active: inactive (dead)

    Jul 15 01:48:34 zodiac-03 systemd[1]: Starting Send hostname and IP to etcd2...
    Jul 15 01:48:35 zodiac-03 etcdctl[24808]: {"host":"10.10.10.203"}
    Jul 15 01:48:35 zodiac-03 systemd[1]: Started Send hostname and IP to etcd2.
    ```

1. ping 和 dig 测试

   ```
   zodiac-01 coreos-install # cat /etc/resolv.conf
   nameserver 10.10.10.214
   zodiac-01 coreos-install # ping zodiac-03.ailab.unisound.com
   PING zodiac-03.ailab.unisound.com (10.10.10.203) 56(84) bytes of data.
   64 bytes from 10.10.10.203: icmp_seq=1 ttl=64 time=0.153 ms
   64 bytes from 10.10.10.203: icmp_seq=2 ttl=64 time=0.198 ms
   64 bytes from 10.10.10.203: icmp_seq=3 ttl=64 time=0.220 ms
   64 bytes from 10.10.10.203: icmp_seq=4 ttl=64 time=0.199 ms
   ^C
   --- zodiac-03.ailab.unisound.com ping statistics ---
   4 packets transmitted, 4 received, 0% packet loss, time 3001ms
   rtt min/avg/max/mdev = 0.153/0.192/0.220/0.028 ms
   zodiac-01 coreos-install # dig @10.10.10.214 zodiac-03.ailab.unisound.com +short
   10.10.10.203
    ```

## 详细配置

## 附注

1. https://coreos.com/docs/launching-containers/launching/getting-started-with-systemd/
1. https://coreos.com/os/docs/latest/cloud-config.html
