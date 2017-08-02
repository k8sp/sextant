from __future__ import with_statement
from fabric.api import *
from fabric.contrib.console import confirm
import fabric.operations as op

new_kernel_version=""
old_kernel_version=""
boot_strapper=""

def prepare():
    run("sed -i '/exclude=*/ s/^/#/' /etc/yum.conf")

def post():
    run("sed -i -e '/exclude=*kernel*/ s/^#//' /etc/yum.conf")

@parallel
def upgrade():
    put("./upgrade_kenerl.sh", "/tmp/upgrade_kenerl.sh")
    result = run("bash /tmp/upgrade_kenerl.sh %s" % boot_strapper)
    if result.failed:
        abort("failed")
    run("grub2-set-default \"CentOS Linux (%s) 7 (Core)\"" % new_kernel_version)

def reset():
    cmd = "grub2-set-default \"CentOS Linux (%s) 7 (Core)\""  % old_kernel_version
    run(cmd)

def check():
    cmd = "if [[ ! -d /usr/src/kernels/%s ]]; then exit 1; fi" % new_kernel_version
    result = run(cmd)
    if result.failed:
        abort(env.host_string + " check failed")

    start = "saved_entry=CentOS Linux (%s) 7 (Core)" % new_kernel_version
    cmd = "if [[ \"$(grub2-editenv list)\" != \"%s\" ]]; then exit 1; fi" % start
    result = run(cmd)
    if result.failed:
        abort(env.host_string + " check failed")

@parallel
def reboot():
    run("systemctl set-default multi-user.target && reboot")

def display():
    run("uname -a")

import yaml

with open("hosts.yaml", 'r') as stream:
    try:
        y = yaml.load(stream)
        env.hosts = y["hosts"]
        env.user = y["user"]
        env.password = y["password"]

        new_kernel_version=y["kernel"]["new_version"]
        old_kernel_version=y["kernel"]["old_version"]
        boot_strapper = y["boot_strapper"]

        #print new_kernel_version, old_kernel_version
        print "grub2-set-default \"CentOS Linux (%s) 7 (Core)\"" % new_kernel_version
    except yaml.YAMLError as exc:
        print(exc)
        abort("load yaml error")

