from __future__ import with_statement
from fabric.api import *
from fabric.contrib.console import confirm
import fabric.operations as op
import yaml
import sys
import re


boot_strapper=""

def prepare_install():
    run("systemctl stop firewalld && systemctl disable firewalld")
    run("wget -O /etc/yum.repos.d/Cloud-init.repo http://%s/static/CentOS7/repo/cloud-init.repo" % boot_strapper)
    run("wget -O /root/post-process.sh http://%s/centos/post-script/00-00-00-00-00-00" % boot_strapper)
    run("wget -O /root http://%s/static/CentOS7/post_cloudinit_provision.sh" % boot_strapper)

def install():
    run("yum --enablerepo=Cloud-init install -y cloud-init docker-engine etcd flannel")
    run("cd /root && bash post-process.sh")
    run("cd /root && bash post_cloudinit_provision.sh")

def re_instal():
    return

def check():
    return

with open("hosts.yaml", 'r') as stream:
    try:
        y = yaml.load(stream)
        env.user = y["user"]
        env.password = y["password"]
        env.hosts = y["hosts"]
        boot_strapper = y["boot_strapper"]
    except yaml.YAMLError as exc:
        print(exc)
        abort("load yaml error")

    


