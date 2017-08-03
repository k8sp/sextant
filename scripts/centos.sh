#!/usr/bin/env bash

GPU_DIR='gpu_drivers'
ABSOLUTE_GPU_DIR="$BSROOT/html/static/CentOS7/$GPU_DIR"
HTTP_GPU_DIR="http://$BS_IP/static/CentOS7/$GPU_DIR"

download_centos_images() {
    VERSION=CentOS7
    mkdir -p $BSROOT/tftpboot
    log info "Downloading syslinux ..."
    wget --quiet -c -N -P $BSROOT/tftpboot https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz || { log fatal "Failed"; exit 1; }
    cd $BSROOT/tftpboot
    tar xzf syslinux-6.03.tar.gz || { log fatal "Failed"; exit 1; }
    cp syslinux-6.03/bios/core/pxelinux.0 $BSROOT/tftpboot || { log fatal "Failed"; exit 1; }
    cp syslinux-6.03/bios/com32/menu/vesamenu.c32 $BSROOT/tftpboot || { log fatal "Failed"; exit 1; }
    cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 $BSROOT/tftpboot || { log fatal "Failed"; exit 1; }
    rm -rf syslinux-6.03 || { log fatal "Failed"; exit 1; } # Clean the untarred.
    log info "Done"

    log info "Downloading CentOS 7 PXE vmlinuz image ..."
    cd $BSROOT/tftpboot
    mkdir -p $BSROOT/tftpboot/CentOS7
    wget --quiet -c -N -P $BSROOT/tftpboot/CentOS7 $cluster_desc_mirror_site/$cluster_desc_centos_version/os/x86_64/images/pxeboot/initrd.img  || { log fatal "Failed"; exit 1; }
    wget --quiet -c -N -P $BSROOT/tftpboot/CentOS7 $cluster_desc_mirror_site/$cluster_desc_centos_version/os/x86_64/images/pxeboot/vmlinuz  || { log fatal "Failed"; exit 1; }
    log info "Done"

    log info "Downloading CentOS 7 ISO ..."
    mkdir -p $BSROOT/html/static/CentOS7
    centos7_src=$cluster_desc_mirror_site/$cluster_desc_centos_version/isos/x86_64/CentOS-7-x86_64-Everything-${cluster_desc_centos_version##*.}.iso
    echo $centos7_src
    wget --quiet -c -N -P $BSROOT/html/static/CentOS7  ${centos7_src} || { log fatal "Failed"; exit 1; }
    log info "Done"
}


generate_pxe_centos_config() {
    log info "Generating pxelinux.cfg ..."
    mkdir -p $BSROOT/tftpboot/pxelinux.cfg
    cat > $BSROOT/tftpboot/pxelinux.cfg/default <<EOF
default CentOS7

label CentOS7
  menu label ^Install CentOS 7
  kernel CentOS7/vmlinuz
  append initrd=CentOS7/initrd.img ks=http://$BS_IP/static/CentOS7/ks.cfg
EOF
    log info "Done"
}


generate_kickstart_config() {
    log info "Generating kickstart config ..."
    mkdir -p $BSROOT/html/static/CentOS7
    cat > $BSROOT/html/static/CentOS7/ks.cfg <<EOF
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Install OS instead of upgrade
install
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --plaintext atlas
# System timezone
timezone Asia/Shanghai
# Use network installation
url --url="http://$BS_IP/static/CentOS7/dvd_content"
# System language
lang en_US
# Firewall configuration
firewall --disabled
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# SELinux configuration
selinux --disabled
# Do not configure the X Window System
skipx

# Halt after installation
reboot
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all
# Disk partitioning information
part / --fstype="xfs" --grow --ondisk=sda --size=1
part swap --fstype="swap" --ondisk=sda --size=8000

repo --name=cloud-init --baseurl=http://$BS_IP/static/CentOS7/repo/cloudinit/
network --onboot on --bootproto dhcp --noipv6

%packages # --ignoremissing
@Base
@Core
cloud-init
docker-engine
etcd
flannel
make
kernel-devel
gcc
wget
#update kernel
kernel-lt
kernel-lt-devel
%end


%pre

%end

%post --log=/root/ks-post-provision.log

wget -O /root/post-process.sh http://$BS_IP/centos/post-script/00-00-00-00-00-00
bash -x /root/post-process.sh

# Imporant: gpu must be installed after the kernel has been installed
wget -P /root $HTTP_GPU_DIR/build_centos_gpu_drivers.sh
bash -x /root/build_centos_gpu_drivers.sh ${cluster_desc_gpu_drivers_version} ${HTTP_GPU_DIR}

wget  -P /root http://$BS_IP/static/CentOS7/post_cloudinit_provision.sh
bash -x /root/post_cloudinit_provision.sh >> /root/cloudinit.log

%end

EOF
    log info "Done"
}


generate_post_cloudinit_script() {
    log info "Generating post cloudinit script ..."
    mkdir -p $BSROOT/html/static/CentOS7
    cat > $BSROOT/html/static/CentOS7/post_cloudinit_provision.sh <<'EOF'
#!/bin/bash
default_iface=$(awk '$2 == 00000000 { print $1  }' /proc/net/route | uniq)
if [[ -z ${bootstrapper_ip} ]]; then
    bootstrapper_ip=$(grep nameserver /etc/resolv.conf|cut -d " " -f2)
fi
printf "Default interface: ${default_iface}\n"
default_iface=`echo ${default_iface} | awk '{ print $1 }'`

mac_addr=`ip addr show dev ${default_iface} | awk '$1 ~ /^link\// { print $2 }'`
printf "Interface: ${default_iface} MAC address: ${mac_addr}\n"


sed -i 's/disable_root: 1/disable_root: 0/g' /etc/cloud/cloud.cfg
sed -i 's/ssh_pwauth:   0/ssh_pwauth:   1/g' /etc/cloud/cloud.cfg
echo "FLANNEL_OPTIONS=\"-iface=${default_iface}\"" >> /etc/sysconfig/flanneld

mkdir -p /var/lib/cloud/seed/nocloud-net/
cd /var/lib/cloud/seed/nocloud-net/

wget -O user-data http://$bootstrapper_ip/cloud-config/${mac_addr}

if [[ ! -z ${etcd_data_path} ]]; then
    sed -i "s@Environment=ETCD_DATA_DIR=.*@Environment=ETCD_DATA_DIR=${etcd_data_path}@" \
    /var/lib/cloud/seed/nocloud-net/user-data
fi

cat > /var/lib/cloud/seed/nocloud-net/meta-data << eof
instance-id: iid-local01
eof

cloud-init init --local
cloud-init init

systemctl stop  NetworkManager
systemctl disable  NetworkManager
systemctl enable docker
EOF
    log info "Done"
}


generate_rpmrepo_config() {
  log info "Generating rpm repo configuration files ..."
  mkdir -p $BSROOT/html/static/CentOS7/repo

   cat > $BSROOT/html/static/CentOS7/repo/cloud-init.repo <<EOF
[Cloud-init]
name=Cloud init Packages for Enterprise Linux 7
baseurl=http://$BS_IP/static/CentOS7/repo/cloudinit/
enabled=1
gpgcheck=0
EOF
  log info "Generating docker repo configuration file....."
  tee $BSROOT/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

  if [[ ${cluster_desc_download_kernel:-y} == n ]] ; then
      REPO_IMAGES='cloud-init docker-engine etcd flannel'
  else
      REPO_IMAGES='cloud-init docker-engine etcd flannel kernel-lt kernel-lt-devel'
  fi 

  # download kernel if the kernel-lt and kernel_lt_devel does not in dir 
  set +e
  KERNEL_LT=$(ls ${BSROOT}/html/static/CentOS7/repo/cloudinit/kernel-lt-*)
  if [[ -n ${KERNEL_LT} ]]; then
      REPO_IMAGES=${REPO_IMAGES}' kernel-lt kernel-devel'
      echo ${REPO_IMAGES}
  fi
  set -e

  docker run --rm -it \
             --volume $BSROOT:/bsroot \
             centos:$cluster_desc_centos_version \
             sh -c  "mv /bsroot/docker.repo  /etc/yum.repos.d/ && \
             /usr/bin/yum -y install epel-release yum-utils createrepo  && \
             /usr/bin/rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org && \
             /usr/bin/rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm && \
             /usr/bin/mkdir  -p /broot/html/static/CentOS7/repo/cloudinit  && \
             /usr/bin/yumdownloader  --enablerepo=elrepo-kernel --resolve \
             --destdir=/bsroot/html/static/CentOS7/repo/cloudinit ${REPO_IMAGES} && \
             /usr/bin/createrepo -v  /bsroot/html/static/CentOS7/repo/cloudinit/" || \
             { log fatal 'Failed to generate  cloud-init repo !' ; exit 1; }

  log info "Done"
}


download_centos_gpu_drivers() {
  log info "Downloading CentOS GPU drivers ..."
  mkdir -p $ABSOLUTE_GPU_DIR
  cp $SEXTANT_DIR/scripts/centos/gpu/nvidia-gpu-mkdev.sh $ABSOLUTE_GPU_DIR
  cp $SEXTANT_DIR/scripts/centos/gpu/build_centos_gpu_drivers.sh $ABSOLUTE_GPU_DIR

  DRIVER_VERSION=${cluster_desc_gpu_drivers_version}
  echo ${cluster_desc_gpu_drivers_version}
  DRIVER_ARCHIVE=NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run
  DRIVER_DOWNLOAD_FROM=http://us.download.nvidia.com/XFree86/Linux-x86_64
  DRIVER_DOWNLOAD_TO=$ABSOLUTE_GPU_DIR
  mkdir -p ${DRIVER_DOWNLOAD_TO}
  wget --quiet -c -N -P ${DRIVER_DOWNLOAD_TO} \
    ${DRIVER_DOWNLOAD_FROM}/${DRIVER_VERSION}/${DRIVER_ARCHIVE} \
    || { log fatal "failed"; }
  log info "Done"
}

