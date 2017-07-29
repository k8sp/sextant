export https_proxy=192.168.16.30:3128
export http_proxy=192.168.16.30:3128

rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
yum --enablerepo=elrepo-kernel install kernel-lt kernel-lt-devel

if [[ ! -f /boot/grub2/grub.cfg ]]; then
    grub2-mkconfig --output=/boot/grub2/grub.cfg
fi

cat /boot/grub2/grub.cfg|grep menuentry
grub2-editenv list
grub2-set-default "CentOS Linux (4.4.60-1.el7.elrepo.x86_64) 7 (Core)"
