from __future__ import with_statement
from fabric.api import *
from fabric.contrib.console import confirm
import fabric.operations as op
import yaml
import sys
import re

def get_mac_addr():
    src_path = "/etc/mac_ip_host"

    cmd = """ default_iface=$(awk '$2 == 00000000 { print $1  }' /proc/net/route | uniq) && 
    default_iface=`echo ${default_iface} | awk '{ print $1 }'` &&
    mac_addr=`ip addr show dev ${default_iface} | awk '$1 ~ /^link\// { print $2 }'` && 
    echo $mac_addr %s $HOSTNAME  > %s
    """ % (env.host_string, src_path)
    run(cmd)

    dst_path = env.host_string + "/mac_ip_host"
    get(src_path, dst_path)

with open("hosts.yaml", 'r') as stream:
    try:
        y = yaml.load(stream)
        env.hosts = y["hosts"]
        env.user = y["user"]
        env.password = y["password"]
    except yaml.YAMLError as exc:
        print(exc)
        abort("load yaml error")



