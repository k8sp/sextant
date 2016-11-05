#!/usr/bin/env bash

# bsroot.sh creates the $PWD/bsroot directory, which is supposed to be
# scp-ed to the bootstrapper server as /bsroot.

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    echo "Usage: $0 <cluster-desc.yml> [\$SEXTANT_DIR/bsroot]"
    exit 1
fi

source $SEXTANT_DIR/bsroot_common.sh

download_centos_images() {
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

    printf "Importing CoreOS signing key ... "
    wget --quiet -c -N -P $BSROOT/tftpboot https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc || { echo "Failed"; exit 1; }
    gpg --import --keyid-format LONG $BSROOT/tftpboot/CoreOS_Image_Signing_Key.asc > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Downloading CoreOS PXE vmlinuz image ... "
    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$VERSION/coreos_production_pxe.vmlinuz || { echo "Failed"; exit 1; }
    rm -f $BSROOT/tftpboot/coreos_production_pxe.vmlinuz > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    ln -s $BSROOT/html/static/$VERSION/coreos_production_pxe.vmlinuz $BSROOT/tftpboot/coreos_production_pxe.vmlinuz > /dev/null 2>&1 || { echo "Failed"; exit 1; }

    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$VERSION/coreos_production_pxe.vmlinuz.sig || { echo "Failed"; exit 1; }
    rm -f $BSROOT/tftpboot/coreos_production_pxe.vmlinuz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    ln -s $BSROOT/html/static/$VERSION/coreos_production_pxe.vmlinuz.sig $BSROOT/tftpboot/coreos_production_pxe.vmlinuz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    cd $BSROOT/tftpboot
    gpg --verify coreos_production_pxe.vmlinuz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Downloading CoreOS PXE CPIO image ... "
    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$VERSION/coreos_production_pxe_image.cpio.gz || { echo "Failed"; exit 1; }
    rm -f $BSROOT/tftpboot/coreos_production_pxe_image.cpio.gz > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    ln -s $BSROOT/html/static/$VERSION/coreos_production_pxe_image.cpio.gz $BSROOT/tftpboot/coreos_production_pxe_image.cpio.gz > /dev/null 2>&1 || { echo "Failed"; exit 1; }

    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$VERSION/coreos_production_pxe_image.cpio.gz.sig || { echo "Failed"; exit 1; }
    rm -f $BSROOT/tftpboot/coreos_production_pxe_image.cpio.gz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    ln -s $BSROOT/html/static/$VERSION/coreos_production_pxe_image.cpio.gz.sig $BSROOT/tftpboot/coreos_production_pxe_image.cpio.gz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    gpg --verify coreos_production_pxe_image.cpio.gz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"
}



generate_pxe_centos_config() {
    printf "Generating pxelinux.cfg ... "
    mkdir -p $BSROOT/tftpboot/pxelinux.cfg
    cat > $BSROOT/tftpboot/pxelinux.cfg/default <<EOF
default coreos

label coreos
  kernel coreos_production_pxe.vmlinuz
  append initrd=coreos_production_pxe_image.cpio.gz cloud-config-url=http://$BS_IP/static/cloud-config/install.sh coreos.autologin
EOF
    echo "Done"
}

check_prerequisites
load_yaml $CLUSTER_DESC cluster_desc_
download_centos_images
generate_pxe_centos_config
generate_registry_config
prepare_cc_server_contents
download_k8s_images
build_bootstrapper_image
generate_tls_assets
prepare_setup_kubectl
generate_addons_config
