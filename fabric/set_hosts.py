from __future__ import with_statement
from fabric.api import *
from fabric.contrib.console import confirm
import fabric.operations as op
import yaml
import sys
import re

mac_ip={}
host_ip={}
set_type=""

def modify_mac_hosts(path, ips):
    import copy
    local = copy.deepcopy(ips)

    #hostname->ip
    hosts = []
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

def set_mac_hosts():
    src_path = "/etc/hosts"
    dst_path = env.host_string + "/hosts"
    get(src_path)
    if set_type == "mac" or set_type == "all":
        modify_mac_hosts(dst_path, mac_ip)
    if set_type == "host" or set_type == "all":
        modify_mac_hosts(dst_path, host_ip)
    put(dst_path, src_path)

def display():
    print host_ip
    print mac_ip

with open("hosts.yaml", 'r') as stream:
    try:
        y = yaml.load(stream)
        env.hosts = y["hosts"]
        env.user = y["user"]
        env.password = y["password"]

        set_type = y["set_type"]
    except yaml.YAMLError as exc:
        print(exc)
        abort("load yaml error")

for h in env.hosts:
    dst_path = h + "/mac_ip_host"
    with open(dst_path, "r") as fp:
        for line in fp.read().split('\n'):
            if len(re.sub('\s*', '', line)) and not line.startswith('#'):
                parts = re.split('\s+', line)
                mac = parts[0].replace(":", "-")
                ip = parts[1]
                host_name = parts[2]

                mac_ip[mac] = ip
                host_ip[host_name] = ip

