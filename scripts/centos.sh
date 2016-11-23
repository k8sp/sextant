#!/usr/bin/env bash

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
    wget --quiet -c -N -P $BSROOT/tftpboot/CentOS7 http://mirrors.163.com/centos/7.2.1511/os/x86_64/images/pxeboot/initrd.img  || { echo "Failed"; exit 1; }
    wget --quiet -c -N -P $BSROOT/tftpboot/CentOS7 http://mirrors.163.com/centos/7.2.1511/os/x86_64/images/pxeboot/vmlinuz  || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Downloading CentOS 7 ISO ... "
    mkdir -p $BSROOT/html/static/CentOS7
    wget --quiet -c -N -P $BSROOT/html/static/CentOS7 http://mirrors.163.com/centos/7.2.1511/isos/x86_64/CentOS-7-x86_64-DVD-1511.iso || { echo "Failed"; exit 1; }
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
part swap --fstype="swap" --ondisk=sda --size=30000

repo --name=cloud-init --baseurl=http://$BS_IP/static/CentOS7/repo/cloudinit/
network --onboot on --bootproto dhcp --noipv6

%packages # --ignoremissing
@Base
@Core
cloud-init
%end


%pre

%end

%post --log=/root/ks-post-provision.log
wget -P /root http://$BS_IP/static/CentOS7/post_provision.sh
bash -x /root/post_provision.sh
%end

%post --nochroot
wget http://$BS_IP/static/CentOS7/post_nochroot_provision.sh
bash -x ./post_nochroot_provision.sh
%end

EOF
    echo "Done"
}


generate_post_provision_script() {
    printf "Generating post provision script ... "
    mkdir -p $BSROOT/html/static/CentOS7
    cat > $BSROOT/html/static/CentOS7/post_provision.sh <<'EOF'
#!/bin/bash
#Obtain devices
#devices=$(lsblk -l |awk '$6=="disk"{print $1}')
# Zap all devices
# NOTICE: dd zero to device mbr will not affect parted printed table,
#         so use parted to remove the part tables

default_iface=$(awk '$2 == 00000000 { print $1  }' /proc/net/route | uniq)

printf "Default interface: ${default_iface}\n"
default_iface=`echo ${default_iface} | awk '{ print $1 }'`

mac_addr=`ip addr show dev ${default_iface} | awk '$1 ~ /^link\// { print $2 }'`
printf "Interface: ${default_iface} MAC address: ${mac_addr}\n"

hostname_str=${mac_addr//:/-}
echo ${hostname_str} >/etc/hostname

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


generate_rpmrepo_config() {
  printf "Generating rpm repo configuration files ..."
  [ ! -d $BSROOT/html/static/CentOS7/repo ] && mkdir  -p $BSROOT/html/static/CentOS7/repo
  cat > $BSROOT/html/static/CentOS7/repo/cloud-init.repo <<EOF
[Cloud-init]
name=Cloud init Packages for Enterprise Linux 7
baseurl=http://$BS_IP/static/CentOS7/repo/cloudinit/
enabled=1
gpgcheck=0
EOF
  docker run --rm -it \
             --volume $BSROOT:/bsroot \
             centos:7.2.1511\
             sh -c  '/usr/bin/yum -y install epel-release yum-utils createrepo  && \
             /usr/bin/mkdir  -p /broot/html/static/CentOS7/repo/cloudinit  && \
             /usr/bin/yumdownloader  --resolve --destdir=/bsroot/html/static/CentOS7/repo/cloudinit cloud-init &&  \
             /usr/bin/createrepo -v  /bsroot/html/static/CentOS7/repo/cloudinit/' ||  \
             { echo 'Failed to generate  cloud-init repo !' ; exit 1; }

  echo "Done"

}


#build_centos_gpu_drivers() {
download_centos_gpu_drivers() {
  printf "Downding CentOS GPU drivers ...\n"
  [ ! -d $BSROOT/html/static/CentOS7/gpu_drivers ] && mkdir  -p $BSROOT/html/static/CentOS7/gpu_drivers

  DRIVER_VERSION=${1:-352.79}
  #DRIVER_VERSION=${1:-352.39}
  CENTOS_VERSION=${3:-7.2.1511}
  DRIVER_ARCHIVE=NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run
  DRIVER_DOWNLOAD_FROM=us.download.nvidia.com/XFree86/Linux-x86_64
  #DRIVER_DOWNLOAD_TO=/home/atlas/bsroot/html/static/CentOS7/gpu/
  DRIVER_DOWNLOAD_TO=$BSROOT/html/static/CentOS7/gpu_drivers/nvidia_installers/
  [ ! -d ${DRIVER_DOWNLOAD_TO} ] && mkdir -p ${DRIVER_DOWNLOAD_TO}
  curl -s -L http://${DRIVER_DOWNLOAD_FROM}/${DRIVER_VERSION}/${DRIVER_ARCHIVE} \
    -z ${DRIVER_DOWNLOAD_TO}/${DRIVER_ARCHIVE} \
    -o ${DRIVER_DOWNLOAD_TO}/${DRIVER_ARCHIVE}
  echo "Done"
  printf "Generating CentOS GPU drivers build script ...\n"
  cat > $BSROOT/html/static/CentOS7/gpu_drivers/build_centos_gpu_drivers.sh <<EOF
#!/bin/bash
#
# Build NVIDIA drivers on CentOS
#
DRIVER_VERSION=\${1:-${DRIVER_VERSION}}
CENTOS_VERSION=\${3:-${CENTOS_VERSION}}

DRIVER_ARCHIVE=NVIDIA-Linux-x86_64-\${DRIVER_VERSION}
DRIVER_ARCHIVE_PATH=\${PWD}/nvidia_installers/\${DRIVER_ARCHIVE}.run
WORK_DIR=\${PWD}/run_files/\${CENTOS_VERSION}
ARTIFACT_DIR=\${WORK_DIR}/\${DRIVER_ARCHIVE}
DRIVER_DOWNLOAD_FROM=10.10.14.253/static/CentOS7/gpu/nvidia_installers/\${DRIVER_ARCHIVE}.run

NVIDIA_DIR=/usr/local/nvidia
NVIDIA_BIN_DIR=/usr/local/nvidia/bin
NVIDIA_LIB_DIR=/usr/local/nvidia/lib64

TOOLS="nvidia-debugdump nvidia-cuda-mps-control nvidia-xconfig nvidia-modprobe nvidia-smi nvidia-cuda-mps-server
nvidia-persistenced nvidia-settings"

if [ ! -f \${DRIVER_ARCHIVE_PATH} ]
then
  echo Downloading NVIDIA Linux drivers version \${DRIVER_VERSION}
  mkdir -p nvidia_installers
  curl -s -L http://\${DRIVER_DOWNLOAD_FROM} \\
    -z \${DRIVER_ARCHIVE_PATH} \\
    -o \${DRIVER_ARCHIVE_PATH}
fi

yum install -y make kernel-devel gcc

#rm -Rf \${PWD}/tmp
mkdir -p \${WORK_DIR}
cp -ul \${DRIVER_ARCHIVE_PATH} \${WORK_DIR}

pushd \${WORK_DIR}
chmod +x \${DRIVER_ARCHIVE}.run
rm -Rf ./\${DRIVER_ARCHIVE}
./\${DRIVER_ARCHIVE}.run -x
cd \${DRIVER_ARCHIVE}
./nvidia-installer -s 
popd
# Create archives with no paths
#sh _export.sh \${WORK_DIR}/\${DRIVER_ARCHIVE} \${DRIVER_VERSION}
tar -C \${ARTIFACT_DIR} -cvj \$(basename -a \${ARTIFACT_DIR}/*.so.*) > libraries-\${DRIVER_VERSION}.tar.bz2
tar -C \${ARTIFACT_DIR} -cvj \${TOOLS} > tools-\${DRIVER_VERSION}.tar.bz2

if [ ! -d \${NVIDIA_DIR} ]
then
  mkdir -p \${NVIDIA_DIR}
fi
if [ ! -d \${NVIDIA_BIN_DIR} ]
then
  mkdir -p \${NVIDIA_BIN_DIR}
  cp ./tools-\${DRIVER_VERSION}.tar.bz2 \${NVIDIA_BIN_DIR}
  pushd \${NVIDIA_BIN_DIR}
  tar -xjf ./tools-\${DRIVER_VERSION}.tar.bz2
  rm -rf ./tools-\${DRIVER_VERSION}.tar.bz2
  popd
fi
if [ ! -d \${NVIDIA_LIB_DIR} ]
then
  mkdir -p \${NVIDIA_LIB_DIR}
  cp ./libraries-\${DRIVER_VERSION}.tar.bz2 \${NVIDIA_LIB_DIR}
  pushd \${NVIDIA_LIB_DIR}

  for LIBRARY_NAME in libcuda libGLESv1_CM \\
    libGL libEGL \\
    libnvidia-cfg libnvidia-encode libnvidia-fbc \\
    libnvidia-ifr libnvidia-ml libnvidia-opencl \\
    libnvcuvid libvdpau
  do
    ln -sf \${LIBRARY_NAME}.so.${DRIVER_VERSION} \${LIBRARY_NAME}.so.1
    ln -sf \${LIBRARY_NAME}.so.1 \${LIBRARY_NAME}.so
  done
  
  ln -sf libOpenCL.so.1.0.0 libOpenCL.so.1
  ln -sf libOpenCL.so.1 libOpenCL.so
  
  ln -sf libGLESv2.so.\${DRIVER_VERSION} libGLESv2.so.2
  ln -sf libGLESv2.so.2 libGLESv2.so
  
  ln -sf libvdpau_nvidia.so.\${DRIVER_VERSION} libvdpau_nvidia.so
  ln -sf libvdpau_trace.so.\${DRIVER_VERSION} libvdpau_trace.so

  tar -xjf ./libraries-\${DRIVER_VERSION}.tar.bz2
  rm -rf ./libraries-\${DRIVER_VERSION}.tar.bz2
  popd
fi
insmod \${WORK_DIR}/\${DRIVER_ARCHIVE}/kernel/uvm/nvidia-uvm.ko

# Count the number of NVIDIA controllers found.
NVDEVS=\`lspci | grep -i NVIDIA\`
N3D=\`echo "\$NVDEVS" | grep "3D controller" | wc -l\`
NVGA=\`echo "\$NVDEVS" | grep "VGA compatible controller" | wc -l\`
N=\`expr \$N3D + \$NVGA - 1\`

for i in \`seq 0 \$N\`; do
        mknod -m 666 /dev/nvidia\$i c 195 \$i
done

mknod -m 666 /dev/nvidiactl c 195 255

# Find out the major device number used by the nvidia-uvm driver
D=\`grep nvidia-uvm /proc/devices | awk '{print \$1}'\`
mknod -m 666 /dev/nvidia-uvm c \$D 0
EOF

  echo "Done"

}



