#!/usr/bin/env bash

GPU_DIR='gpu_drivers'
ABSOLUTE_GPU_DIR="$BSROOT/html/static/CentOS7/$GPU_DIR"
HTTP_GPU_DIR="http://$BS_IP/static/CentOS7/$GPU_DIR"

download_centos_images() {
    VERSION=CentOS7
    mkdir -p $BSROOT/tftpboot
    printf "Downloading syslinux ... "
    wget --quiet -c -N -P $BSROOT/tftpboot https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz || { echo "Failed"; exit 1; }
    cd $BSROOT/tftpboot
    tar xzf syslinux-6.03.tar.gz || { echo "Failed"; exit 1; }
    cp syslinux-6.03/bios/core/pxelinux.0 $BSROOT/tftpboot || { echo "Failed"; exit 1; }
    cp syslinux-6.03/bios/com32/menu/vesamenu.c32 $BSROOT/tftpboot || { echo "Failed"; exit 1; }
    cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 $BSROOT/tftpboot || { echo "Failed"; exit 1; }
    rm -rf syslinux-6.03 || { echo "Failed"; exit 1; } # Clean the untarred.
    echo "Done"

    printf "Downloading CentOS 7 PXE vmlinuz image ... "
    cd $BSROOT/tftpboot
    mkdir -p $BSROOT/tftpboot/CentOS7
    wget --quiet -c -N -P $BSROOT/tftpboot/CentOS7 http://mirrors.163.com/centos/$cluster_desc_centos_version/os/x86_64/images/pxeboot/initrd.img  || { echo "Failed"; exit 1; }
    wget --quiet -c -N -P $BSROOT/tftpboot/CentOS7 http://mirrors.163.com/centos/$cluster_desc_centos_version/os/x86_64/images/pxeboot/vmlinuz  || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Downloading CentOS 7 ISO ... "
    mkdir -p $BSROOT/html/static/CentOS7
    wget --quiet -c -N -P $BSROOT/html/static/CentOS7 http://mirrors.163.com/centos/$cluster_desc_centos_version/isos/x86_64/CentOS-7-x86_64-Everything-1611.iso || { echo "Failed"; exit 1; }
    echo "Done"
}


generate_pxe_centos_config() {
    printf "Generating pxelinux.cfg ... "
    mkdir -p $BSROOT/tftpboot/pxelinux.cfg
    cat > $BSROOT/tftpboot/pxelinux.cfg/default <<EOF
default CentOS7

label CentOS7
  menu label ^Install CentOS 7
  kernel CentOS7/vmlinuz
  append initrd=CentOS7/initrd.img ks=http://$BS_IP/static/CentOS7/ks.cfg
EOF
    echo "Done"
}


generate_kickstart_config() {
    printf "Generating kickstart config ... "
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
docker-engine-${cluster_desc_docker_engine_version}
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

wget -P /root http://$BS_IP/static/CentOS7/set-hostname.sh
bash -x /root/set-hostname.sh

wget -P /root http://$BS_IP/static/CentOS7/update-kernel.sh
bash -x /root/update-kernel.sh

# Imporant: gpu must be installed after the kernel has been installed
wget -P /root $HTTP_GPU_DIR/build_centos_gpu_drivers.sh
bash -x /root/build_centos_gpu_drivers.sh ${cluster_desc_gpu_drivers_version} ${HTTP_GPU_DIR} ${cluster_desc_centos_version}

wget  -P /root http://$BS_IP/static/CentOS7/post_cloudinit_provision.sh
bash -x /root/post_cloudinit_provision.sh >> /root/cloudinit.log

%end

%post --nochroot
wget http://$BS_IP/static/CentOS7/post_nochroot_provision.sh
bash -x ./post_nochroot_provision.sh
%end

%post
wget  -P /root http://$BS_IP/static/CentOS7/post_yum_repo.sh
bash -x /root/post_yum_repo.sh
%end

EOF
    echo "Done"
}


generate_post_provision_script() {
    printf "Generating post provision script ... "
    mkdir -p $BSROOT/html/static/CentOS7
    cat > "$BSROOT/html/static/CentOS7/set-hostname.sh" <<'EOF'
#!/bin/bash

default_iface=$(awk '$2 == 00000000 { print $1  }' /proc/net/route | uniq)
printf "Default interface: ${default_iface}\n"
default_iface=`echo ${default_iface} | awk '{ print $1 }'`
mac_addr=`ip addr show dev ${default_iface} | awk '$1 ~ /^link\// { print $2 }'`
printf "Interface: ${default_iface} MAC address: ${mac_addr}\n"

hostname_str=${mac_addr//:/-}
echo ${hostname_str} >/etc/hostname

EOF

cat > $BSROOT/html/static/CentOS7/update-kernel.sh <<'EOF'
#!/bin/bash

# For install multi-kernel, set the first line kernel in grub list as default to boot
grub2-set-default 0

# load overlay for docker storage driver
echo "overlay" > /etc/modules-load.d/overlay.conf

# set overaly as docker storage driver instead of devicemapper (the default one on centos)
sed -i -e '/^ExecStart=/ s/$/ --storage-driver=overlay/' /etc/systemd/system/multi-user.target.wants/docker.service

EOF

    echo "Done"
}


generate_post_cloudinit_script() {
    printf "Generating post cloudinit script ... "
    mkdir -p $BSROOT/html/static/CentOS7
    cat > $BSROOT/html/static/CentOS7/post_cloudinit_provision.sh <<'EOF'
#!/bin/bash
default_iface=$(awk '$2 == 00000000 { print $1  }' /proc/net/route | uniq)
bootstrapper_ip=$(grep nameserver /etc/resolv.conf|cut -d " " -f2)
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

cat > /var/lib/cloud/seed/nocloud-net/meta-data << eof
instance-id: iid-local01
eof

cloud-init init --local
cloud-init init

systemctl stop  NetworkManager
systemctl disable  NetworkManager
systemctl enable docker.service
EOF
    echo "Done"

}


generate_post_nochroot_provision_script() {
    printf "Generating post nochroot provision script ... "
    mkdir -p $BSROOT/html/static/CentOS7
    cat > $BSROOT/html/static/CentOS7/post_nochroot_provision.sh <<'EOF'
#!/bin/bash

EOF
    echo "Done"
}

generate_post_yum_repo_script() {
    printf "Generating post nochr  script ... "
    mkdir -p $BSROOT/html/static/CentOS7
    cat > $BSROOT/html/static/CentOS7/post_yum_repo.sh <<'EOF'
#!/bin/bash
BootStrapper_ip=$(grep nameserver /etc/resolv.conf|cut -d " " -f2)
DownLoad_Files="CentOS7-Base-163.repo CentOS7-Base.repo"
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
for i in $DownLoad_Files
do
 wget -P /etc/yum.repos.d/   http://$BootStrapper_ip/static/CentOS7/repo/$i
done
yum clean all
yum makecache
EOF
    echo "Done"
}

generate_rpmrepo_config() {
  printf "Generating rpm repo configuration files ..."
  [ ! -d $BSROOT/html/static/CentOS7/repo ] && mkdir  -p $BSROOT/html/static/CentOS7/repo
  if [[ $cluster_desc_set_yum_repo == "bootstrapper" ]]; then
    cat > $BSROOT/html/static/CentOS7/repo/CentOS7-Base.repo <<EOF
[Base]
name=Base Packages for Enterprise Linux 7
baseurl=http://$BS_IP/static/CentOS7/dvd_content/
enabled=1
gpgcheck=0
EOF
  elif [[ $cluster_desc_set_yum_repo == "mirrors.163.com" ]];then
    wget -P $BSROOT/html/static/CentOS7/repo/ http://mirrors.163.com/.help/CentOS7-Base-163.repo
  fi

   cat > $BSROOT/html/static/CentOS7/repo/cloud-init.repo <<EOF
[Cloud-init]
name=Cloud init Packages for Enterprise Linux 7
baseurl=http://$BS_IP/static/CentOS7/repo/cloudinit/
enabled=1
gpgcheck=0
EOF
  printf "Generating docker repo configuration file....."
  tee $BSROOT/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

  docker run --rm -it \
             --volume $BSROOT:/bsroot \
             centos:$cluster_desc_centos_version \
             sh -c  'mv /bsroot/docker.repo  /etc/yum.repos.d/ && \
             /usr/bin/yum -y install epel-release yum-utils createrepo  && \
             /usr/bin/rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org && \
             /usr/bin/rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm && \
             /usr/bin/mkdir  -p /broot/html/static/CentOS7/repo/cloudinit  && \
             /usr/bin/yumdownloader  --enablerepo=elrepo-kernel --resolve \
             --destdir=/bsroot/html/static/CentOS7/repo/cloudinit cloud-init \
             docker-engine-'${cluster_desc_docker_engine_version}' etcd flannel \
             kernel-lt kernel-lt-devel && \
             /usr/bin/createrepo -v  /bsroot/html/static/CentOS7/repo/cloudinit/' || \
             { echo 'Failed to generate  cloud-init repo !' ; exit 1; }

  echo "Done"
}


download_centos_gpu_drivers() {
  printf "Generating CentOS GPU drivers build script ...\n"
  cat > /usr/local/bin/nvidia-gpu-mkdev.sh <<'EOF'
#!/bin/bash

/sbin/modprobe nvidia
# Count the number of NVIDIA controllers found.
NVDEVS=`lspci | grep -i NVIDIA`
N3D=`echo "$NVDEVS" | grep "3D controller" | wc -l`
NVGA=`echo "$NVDEVS" | grep "VGA compatible controller" | wc -l`
N=`expr $N3D + $NVGA - 1`

for i in `seq 0 $N`; do
  mknod -m 666 /dev/nvidia$i c 195 $i
done

mknod -m 666 /dev/nvidiactl c 195 255

/sbin/modprobe nvidia-uvm
# Find out the major device number used by the nvidia-uvm driver
D=\`grep nvidia-uvm /proc/devices | awk '{print \$1}'\`;
mknod -m 666 /dev/nvidia-uvm c \$D 0

EOF

  cat > $ABSOLUTE_GPU_DIR/build_centos_gpu_drivers.sh <<'EOF'
#!/bin/bash
#
# Build NVIDIA drivers on CentOS
#
DRIVER_VERSION=$1
HTTP_GPU_DIR=$2
CENTOS_VERSION=$3

DRIVER_ARCHIVE=NVIDIA-Linux-x86_64-${DRIVER_VERSION}
DRIVER_ARCHIVE_PATH=${PWD}/nvidia_installers/${DRIVER_ARCHIVE}.run
WORK_DIR=${PWD}/run_files/${CENTOS_VERSION}
ARTIFACT_DIR=${WORK_DIR}/${DRIVER_ARCHIVE}
NVIDIA_DIR=/usr/local/nvidia
NVIDIA_BIN_DIR=/usr/local/nvidia/bin
NVIDIA_LIB_DIR=/usr/local/nvidia/lib64
TOOLS="nvidia-debugdump nvidia-cuda-mps-control nvidia-xconfig nvidia-modprobe nvidia-smi nvidia-cuda-mps-server nvidia-persistenced nvidia-settings"

download_nvidia_gpu_drivers(){
  if [ ! -f ${DRIVER_ARCHIVE_PATH} ]
  then
    echo Downloading NVIDIA Linux drivers version ${DRIVER_VERSION}
    mkdir -p nvidia_installers
    wget --quiet -c -N -P nvidia_installers ${HTTP_GPU_DIR}/${DRIVER_ARCHIVE}.run || { echo "Failed"; exit 1; }
  fi
}


build_lib_and_ko() {
  mkdir -p ${WORK_DIR}
  cp -ul ${DRIVER_ARCHIVE_PATH} ${WORK_DIR}

  pushd ${WORK_DIR}
  chmod +x ${DRIVER_ARCHIVE}.run
  rm -Rf ./${DRIVER_ARCHIVE}
  ./${DRIVER_ARCHIVE}.run -x
  cd ${DRIVER_ARCHIVE}
  ./nvidia-installer -s
  popd
  # Create archives with no paths
  tar -C ${ARTIFACT_DIR} -cvj $(basename -a ${ARTIFACT_DIR}/*.so.*) > libraries-${DRIVER_VERSION}.tar.bz2
  tar -C ${ARTIFACT_DIR} -cvj ${TOOLS} > tools-${DRIVER_VERSION}.tar.bz2
}


install_lib_and_ko() {
  if [ ! -d ${NVIDIA_DIR} ]
  then
    mkdir -p ${NVIDIA_DIR}
  fi
  if [ ! -d ${NVIDIA_BIN_DIR} ]
  then
    mkdir -p ${NVIDIA_BIN_DIR}
    cp ./tools-${DRIVER_VERSION}.tar.bz2 ${NVIDIA_BIN_DIR}
    pushd ${NVIDIA_BIN_DIR}
    tar -xjf ./tools-${DRIVER_VERSION}.tar.bz2
    rm -rf ./tools-${DRIVER_VERSION}.tar.bz2
    popd
  fi
  if [ ! -d ${NVIDIA_LIB_DIR} ]
  then
    mkdir -p ${NVIDIA_LIB_DIR}
    cp ./libraries-${DRIVER_VERSION}.tar.bz2 ${NVIDIA_LIB_DIR}
    pushd ${NVIDIA_LIB_DIR}

    for LIBRARY_NAME in libcuda libGLESv1_CM \
      libGL libEGL \
      libnvidia-cfg libnvidia-encode libnvidia-fbc \
      libnvidia-ifr libnvidia-ml libnvidia-opencl \
      libnvcuvid libvdpau
    do
      ln -sf ${LIBRARY_NAME}.so.${DRIVER_VERSION} ${LIBRARY_NAME}.so.1
      ln -sf ${LIBRARY_NAME}.so.1 ${LIBRARY_NAME}.so
    done

    ln -sf libOpenCL.so.1.0.0 libOpenCL.so.1
    ln -sf libOpenCL.so.1 libOpenCL.so

    ln -sf libGLESv2.so.${DRIVER_VERSION} libGLESv2.so.2
    ln -sf libGLESv2.so.2 libGLESv2.so

    ln -sf libvdpau_nvidia.so.${DRIVER_VERSION} libvdpau_nvidia.so
    ln -sf libvdpau_trace.so.${DRIVER_VERSION} libvdpau_trace.so

    tar -xjf ./libraries-${DRIVER_VERSION}.tar.bz2
    rm -rf ./libraries-${DRIVER_VERSION}.tar.bz2
    popd
  fi
}
download_nvidia_gpu_drivers
build_lib_and_ko
install_lib_and_ko
/bin/bash /usr/local/bin/nvidia-gpu-mkdev.sh
echo "/bin/bash /usr/local/bin/nvidia-gpu-mkdev.sh" >>/etc/rc.local
chmod +x /etc/rc.local

EOF
  echo "Done"

  printf "Downloading CentOS GPU drivers ...\n"

  DRIVER_VERSION=${cluster_desc_gpu_drivers_version}
  echo ${cluster_desc_gpu_drivers_version}
  DRIVER_ARCHIVE=NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run
  DRIVER_DOWNLOAD_FROM=http://us.download.nvidia.com/XFree86/Linux-x86_64
  DRIVER_DOWNLOAD_TO=$ABSOLUTE_GPU_DIR
  mkdir -p ${DRIVER_DOWNLOAD_TO}
  wget --quiet -c -N -P ${DRIVER_DOWNLOAD_TO} \
    ${DRIVER_DOWNLOAD_FROM}/${DRIVER_VERSION}/${DRIVER_ARCHIVE} \
    || { echo "Failed"; exit 1; }
  echo "Done"
}
