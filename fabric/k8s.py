from __future__ import with_statement
from fabric.api import *
from fabric.contrib.console import confirm
import fabric.operations as op
import yaml
import sys
import re


boot_strapper=""
set_mac_hostname=""
docker_data_path=""
etcd_data_path=""

def prepare():
    run("systemctl stop firewalld && systemctl disable firewalld")
    run("wget -O /etc/yum.repos.d/Cloud-init.repo http://%s/static/CentOS7/repo/cloud-init.repo" % boot_strapper)
    run("wget -O /root/post-process.sh http://%s/centos/post-script/00-00-00-00-00-00" % boot_strapper)
    run("wget -O /root http://%s/static/CentOS7/post_cloudinit_provision.sh" % boot_strapper)

def install():
    run("yum --enablerepo=Cloud-init install -y cloud-init docker-engine etcd flannel")
    run("""cd /root 
        && export set_mac_hostname=%s 
        && export docker_data_path=%s 
        && bash post-process.sh""" % (set_mac_hostname, docker_data_path))

    if len(etcd_data_path) > 0 :
        run("id -u etcd &>/dev/null || useradd etcd")
        run("mkdir -p %s && chown etcd -R %s" % (etcd_data_path, etcd_data_path))

    run(""" cd /root
        && export bootstrapper_ip=%s 
        && export etcd_data_path=%s 
        && bash post_cloudinit_provision.sh""" % (boot_strapper, etcd_data_path))

def rm_clouinit_cache():
    run("rm -rf /var/lib/cloud/instances/iid-local01")

def start_etcd():
    run("""systemctl daemon-reload
        && systemctl stop etcd
        && systemctl enable etcd 
        && systemctl start etcd""")

with open("hosts.yaml", 'r') as stream:
    try:
        y = yaml.load(stream)
        env.user = y["user"]
        env.password = y["password"]
        env.hosts = y["hosts"]
        boot_strapper = y["boot_strapper"]

        set_mac_hostname = y["set_mac_hostname"]
        docker_data_path = y["docker_data_path"]
        etcd_data_path = y["etcd_data_path"]
    except yaml.YAMLError as exc:
        print(exc)
        abort("load yaml error")

    


