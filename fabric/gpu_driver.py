from __future__ import with_statement
from fabric.api import *
from fabric.contrib.console import confirm
import fabric.operations as op
import yaml
import sys

driver_version=""
http_gpu_dir=""
boot_strapper=""

def prepare():
    cmd = """setenforce 0 
        && sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config 
        && cat /etc/selinux/config | grep SELINUX"""
    run(cmd)

def install():
    # Imporant: gpu must be installed after the kernel has been installed
    run("wget -P /root %s/build_centos_gpu_drivers.sh" % http_gpu_dir)
    cmd = "bash -x /root/build_centos_gpu_drivers.sh %s %s" % (driver_version, http_gpu_dir)
    run(cmd)

#@parallel
def check():
    cmd="ret=`nvidia-smi | grep  \"Driver Version\" | grep %s` ; if [[ -z $ret  ]]; then exit 1; fi " % driver_version
    result = run(cmd)
    if result.failed:
        abort(env.host_string + ": check failed")

with open("hosts.yaml", 'r') as stream:
    try:
        y = yaml.load(stream)
        env.hosts = y["hosts"]
        env.user = y["user"]
        env.password = y["password"]

        boot_strapper = y["boot_strapper"]
        driver_version = y["gpu"]["driver_version"]

        http_gpu_dir="http://%s/static/CentOS7/gpu_drivers" % boot_strapper
    except yaml.YAMLError as exc:
        print(exc)
        abort("load yaml error")


