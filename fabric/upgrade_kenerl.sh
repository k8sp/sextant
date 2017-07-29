#!/bin/bash
export https_proxy=192.168.16.30:3128
export http_proxy=192.168.16.30:3128

rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
yum --enablerepo=elrepo-kernel -y -d1 install kernel-lt kernel-lt-devel 

if [[ ! -f /boot/grub2/grub.cfg ]]; then
    grub2-mkconfig --output=/boot/grub2/grub.cfg
fi
