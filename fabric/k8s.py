from __future__ import with_statement
from fabric.api import *
from fabric.contrib.console import confirm
import fabric.operations as op
import yaml
import sys
import re


#mac_addr->ip
mac_host={}

def get_mac_addr():
    cmd = """ default_iface=$(awk '$2 == 00000000 { print $1  }' /proc/net/route | uniq) && 
    default_iface=`echo ${default_iface} | awk '{ print $1 }'` &&
    mac_addr=`ip addr show dev ${default_iface} | awk '$1 ~ /^link\// { print $2 }'` && 
    echo $mac_addr | tr ':' '-'
    """
    run(cmd)

def set_mac_hosts():
    import copy
    local = copy.deepcopy(mac_host)

    #hostname->ip
    hosts = []
    path = "/etc/hosts"
    with open(path, "r") as fp:
        for line in fp.read().split('\n'):
            if len(re.sub('\s*', '', line)) and not line.startswith('#'):
                parts = re.split('\s+', line)
                ip = parts[0]
                host_name = " ".join(parts[1:])
                hosts.append([host_name, ip])
        fp.close()

    for n in hosts:
        if n[0] in local:
            n[1] = local[n[0]]
            local[n[0]]= ""

    with open(path, "w") as fw:
        for n in hosts:
            fw.write("%s %s\n" % (n[1], n[0]) )
        for n in local:
            if len(local[n]) > 0:
                fw.write("%s %s\n" % (local[n], n) )
        fw.close()

with open("hosts.yaml", 'r') as stream:
    try:
        y = yaml.load(stream)
        env.user = y["user"]
        env.password = y["password"]
        env.hosts = y["hosts"]

        nodes = y["mac_host_dns"]
        for t in nodes:
            mac_host[t["mac"]]=t["host"]

        print mac_host
    except yaml.YAMLError as exc:
        print(exc)
        abort("load yaml error")

    


