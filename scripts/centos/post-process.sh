#!/usr/bin/env bash

set_hostname() {
    default_iface=$(awk '$2 == 00000000 { print $1   }' /proc/net/route | uniq)
    
    printf "Default interface: ${default_iface}\n"
    default_iface=`echo ${default_iface} | awk '{ print $1  }'`
    mac_addr=`ip addr show dev ${default_iface} | awk '$1 ~ /^link\// { print $2  }'`
    
    printf "Interface: ${default_iface} MAC address: ${mac_addr}\n"
    
    hostname_str=${mac_addr//:/-}
    echo ${hostname_str} >/etc/hostname
}

update_kernel() {
    # For install multi-kernel, set the first line kernel in grub list as default to boot
    grub2-set-default 0
    # load overlay for docker storage driver
    echo "overlay" > /etc/modules-load.d/overlay.conf
    # set overaly as docker storage driver instead of devicemapper (the default one on centos)
    sed -i -e '/^ExecStart=/ s/$/ --storage-driver=overlay/' /etc/systemd/system/multi-user.target.wants/docker.service
}


set_yum_repo(){

BS_IP=$1
cluster_desc_set_yum_repo=$2

if [[ $cluster_desc_set_yum_repo == "bootstrapper" ]]; then

cat >/etc/yum.repos.d/Local.repo << EOF
[LocalRepo]
name=Local Repository
baseurl=http://$BS_IP/static/CentOS7/dvd_content/
enabled=1
gpgcheck=0

EOF

else

    cp /etc/yum.repos.d/CentOS-Base.repo{,.bak}
    sed -i -e 's/mirrorlist/#mirrorlist/@g' /etc/yum.repos.d/CentOS-Base.repo
    sed -i -e 's@#baseurl=http://[^/]*@baseurl=http://$cluster_desc_set_yum_repo@g' /etc/yum.repos.d/CentOS-Base.repo

fi

yum clean all
yum makecache

}



set_hostname
update_kernel
set_yum_repo
