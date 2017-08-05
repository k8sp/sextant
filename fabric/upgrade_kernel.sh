#!/bin/bash
#export https_proxy=192.168.16.30:3128
#export http_proxy=192.168.16.30:3128

if [[ $# > 0 ]]; then
    wget -O /etc/yum.repos.d/Cloud-init.repo http://$1/static/CentOS7/repo/cloud-init.repo
    yum --enablerepo=Cloud-init -y -d1 install kernel-lt kernel-lt-devel 
else
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
    yum --enablerepo=elrepo-kernel -y -d1 install kernel-lt kernel-lt-devel 
fi

if [[ ! -f /boot/grub2/grub.cfg ]]; then
    grub2-mkconfig --output=/boot/grub2/grub.cfg
fi
