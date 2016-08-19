#!/bin/bash
# NOTICE: put all prepared files in /bsroot
# FIXME: DEFAULT_IPV4 may not accessible by clients?
DEFAULT_IPV4=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`

mkdir -p /bsroot
mkdir -p /bsroot/html
mkdir -p /bsroot/tftpboot
# download stuff used by PXE and tftp
cd /bsroot/tftpboot
# download syslinux and unzip
wget https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz
tar xzf syslinux-6.03.tar.gz
cp syslinux-6.03/bios/core/pxelinux.0 /bsroot/tftpboot
cp syslinux-6.03/bios/com32/menu/vesamenu.c32 /bsroot/tftpboot
# download and import coreos pubkey
wget https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc
gpg --import --keyid-format LONG /bsroot/tftpboot/CoreOS_Image_Signing_Key.asc
# download coreos pxe images
wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz
wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz.sig
wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz
wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz.sig
gpg --verify coreos_production_pxe.vmlinuz.sig
if [ $? -ne 0 ] ; then
  exit 1
fi
gpg --verify coreos_production_pxe_image.cpio.gz.sig
if [ $? -ne 0 ] ; then
  exit 1
fi
mkdir pxelinux.cfg
# config pxe
cat > /bsroot/tftpboot/pxelinux.cfg/default <<EOF
default coreos

label coreos
  kernel coreos_production_pxe.vmlinuz
  append initrd=coreos_production_pxe_image.cpio.gz cloud-config-url=http://{$DEFAULT_IPV4}:8088/cloud-configs/install.sh coreos.autologin
EOF
# download install.sh
mkdir -p /bsroot/html/cloud-configs
cd /bsroot/html/cloud-configs
wget https://raw.githubusercontent.com/k8sp/auto-install/bootstrapper_ng/cloud-config-server/install.sh
# download coreos image for cc server to serve
mkdir -p /bsroot/html/current
cd /bsroot/html/current
wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_image.bin.bz2
wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_image.bin.bz2.sig
gpg --verify coreos_production_image.bin.bz2.sig
if [ $? -ne 0 ] ; then
  exit 1
fi
# download kubernetes images, bootstrapper registry will load it later
docker pull typhoon1986/hyperkube-amd64:v1.2.0
docker pull typhoon1986/pause:2.0
docker save typhoon1986/hyperkube-amd64:v1.2.0 > hyperkube-amd64_v1.2.0.tar
docker save typhoon1986/pause:2.0 > pause_2.0.tar
