from __future__ import with_statement
from fabric.api import *
from fabric.contrib.console import confirm


env.user = 'root'
env.password = '112233'
env.hosts = ['172.19.32.197']

def prepare():
    run("sed -i '/exclude=*/ s/^/#/' /etc/yum.conf")

def post():
    run("sed -i -e '/exclude=*kernel*/ s/^#//' /etc/yum.conf")

def upgrade():
    put("./upgrade_kenerl.sh", "upgrade_kenerl.sh")
    result = run("upgrade_kenerl.sh")
    if result.faild:
        abort("faild")

def load_hosts():
    import yaml

    with open("hosts.yaml", 'r') as stream:
        try:
            print(yaml.load(stream))
        except yaml.YAMLError as exc:
            print(exc)

