#!/bin/bash
# NOTICE: put all prepared files in /bsroot
# FIXME: DEFAULT_IPV4 may not accessible by clients?
#DEFAULT_IPV4=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
DEFAULT_IPV4=`grep "bootstrapper:" cloud-config-server/template/unisound-ailab/build_config.yml | awk '{print $2}' | sed 's/ //g'`
echo "using bootstrapper IP: $DEFAULT_IPV4..."

CURR_DIR=$(pwd)
mkdir -p /bsroot
mkdir -p /bsroot/html/static
mkdir -p /bsroot/tftpboot
mkdir -p /bsroot/config
mkdir -p /bsroot/tls
# -------------check if tools used by this script are installed -------------
check_prerequisites() {
  met=0
  for tool in wget tar gpg docker; do
    command -v $tool >/dev/null 2>&1 || { echo "Install $tool before run this script"; met=1; }
  done
  return $met
}
# -------------download stuff used by PXE and tftp-------------
download_pxe_images() {
  cd /bsroot/tftpboot
  # download syslinux and unzip
  wget -c https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz
  tar xzf syslinux-6.03.tar.gz
  cp syslinux-6.03/bios/core/pxelinux.0 /bsroot/tftpboot
  cp syslinux-6.03/bios/com32/menu/vesamenu.c32 /bsroot/tftpboot
  cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 /bsroot/tftpboot
  # download and import coreos pubkey
  wget https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc
  gpg --import --keyid-format LONG /bsroot/tftpboot/CoreOS_Image_Signing_Key.asc
  # download coreos pxe images
  wget -c https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz
  wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz.sig
  gpg --verify coreos_production_pxe.vmlinuz.sig
  if [ $? -ne 0 ] ; then
    exit 1
  fi
  wget -c https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz
  wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz.sig
  gpg --verify coreos_production_pxe_image.cpio.gz.sig
  if [ $? -ne 0 ] ; then
    echo "download coreos pxe image error, try rerun this script please."
    exit 1
  fi
}
gen_pxe_config() {
  mkdir pxelinux.cfg
  # gen default pxe config
  cat > /bsroot/tftpboot/pxelinux.cfg/default <<EOF
default coreos

label coreos
  kernel coreos_production_pxe.vmlinuz
  append initrd=coreos_production_pxe_image.cpio.gz cloud-config-url=http://$DEFAULT_IPV4:8081/static/cloud-configs/install.sh coreos.autologin
EOF
}

gen_dnsmasq_config() {
  cat > /bsroot/config/dnsmasq.conf <<EOF
  interface=eth0
  bind-interfaces
  domain=k8s.baifendian.com
  user=root
  dhcp-range=192.168.8.102,192.168.8.200,255.255.255.0,12h
  log-dhcp

  dhcp-boot=pxelinux.0

  dhcp-option=3,192.168.8.101

  dhcp-option=6,192.168.8.101,8.8.8.8
  no-hosts
  expand-hosts
  no-resolv

  local=/k8s.baifendian.com/
  domain-needed

  dhcp-option=28,192.168.8.255

  #dhcp-option=42,0.0.0.0
  pxe-prompt="Press F8 for menu.", 60
  pxe-service=x86PC, "Install CoreOS from network server", pxelinux
  enable-tftp
  tftp-root=/bsroot/tftpboot
EOF
}

gen_registry_config() {
  mkdir -p /bsroot/registry
  cat > /bsroot/config/registry.yml <<EOF
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /bsroot/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
}

# -------------download stuff used by cloud-config-server-------------
prepare_cc_server_contents() {
  # put ceph install script in /bsroot/html/static/ceph
  cd $CURR_DIR
  mkdir -p /bsroot/html/static/ceph
  cp ./cloud-config-server/install-ceph/install-mon.sh /bsroot/html/static/ceph/install-mon.sh
  cp ./cloud-config-server/install-ceph/install-osd.sh /bsroot/html/static/ceph/install-osd.sh

  cd /bsroot/html/static
  wget -c -O setup-network-environment-1.0.1 https://github.com/kelseyhightower/setup-network-environment/releases/download/1.0.1/setup-network-environment
  wget -c https://github.com/typhoonzero/kubernetes_binaries/releases/download/v1.2.0/kubelet
  chmod +x kubelet
  # copy install.sh
  mkdir -p /bsroot/html/static/cloud-configs
  cd $CURR_DIR
  cp ./cloud-config-server/install.sh /bsroot/html/static/cloud-configs
  # put cloud-config.template in /bsroot/config
  cp ./cloud-config-server/template/cloud-config.template /bsroot/config
  # put cluster-desc.yml to /bsroot/config
  cp ./cloud-config-server/template/unisound-ailab/build_config.yml /bsroot/config/cluster-desc.yml
  # download coreos image for cc server to serve
  # FIXME: current dir should be a symbol link
  mkdir -p /bsroot/html/static/current
  cd /bsroot/html/static/current
  wget https://stable.release.core-os.net/amd64-usr/current/version.txt
  VERSION=$(cat version.txt | grep 'COREOS_VERSION=' | cut -f 2 -d '=')
  echo "Detected most recent version:" $VERSION
  if [[ ! -d $VERSION ]]; then
    mkdir -p /bsroot/html/static/$VERSION
  fi
  cd /bsroot/html/static/$VERSION
  wget -c https://stable.release.core-os.net/amd64-usr/current/coreos_production_image.bin.bz2
  wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_image.bin.bz2.sig
  gpg --verify coreos_production_image.bin.bz2.sig

  if [ $? -ne 0 ] ; then
    echo "download nginx coreos image error, try rerun this script please."
    exit 1
  fi
}

# -------------download k8s image for later start.sh to push-------------
download_k8s_images () {
  cd /bsroot
  docker pull typhoon1986/hyperkube-amd64:v1.2.0
  docker save typhoon1986/hyperkube-amd64:v1.2.0 > hyperkube-amd64_v1.2.0.tar
  docker pull typhoon1986/pause:2.0
  docker save typhoon1986/pause:2.0 > pause_2.0.tar
  docker pull typhoon1986/flannel:0.5.5
  docker save typhoon1986/flannel:0.5.5 > flannel_0.5.5.tar
}

download_ceph_images() {
  cd /bsroot
  docker pull ceph/daemon
  docker save ceph/daemon > ceph_daemon.tar
}

# -------------do the steps-------------
check_prerequisites || exit 1
download_pxe_images
gen_pxe_config
gen_dnsmasq_config
gen_registry_config
prepare_cc_server_contents
download_k8s_images
download_ceph_images

