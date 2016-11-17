#!/usr/bin/env bash


check_coreos_version () {
    printf "Checking the CoreOS version ... "
    VERSION=$(curl -s https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$cluster_desc_coreos_version/version.txt | grep 'COREOS_VERSION=' | cut -f 2 -d '=')
    if [[ $VERSION == "" ]]; then
        echo "Failed"; exit 1;
    fi
    echo "Done with coreos channel: " $cluster_desc_coreos_channel "version: " $VERSION
}


download_pxe_images() {
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
    cd $BSROOT/tftpboot/
    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$VERSION/coreos_production_pxe.vmlinuz || { echo "Failed"; exit 1; }
    rm -f $BSROOT/tftpboot/coreos_production_pxe.vmlinuz > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    ln -s ../html/static/$VERSION/coreos_production_pxe.vmlinuz ./ > /dev/null 2>&1 || { echo "Failed"; exit 1; }

    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$VERSION/coreos_production_pxe.vmlinuz.sig || { echo "Failed"; exit 1; }
    rm -f $BSROOT/tftpboot/coreos_production_pxe.vmlinuz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    ln -s ../html/static/$VERSION/coreos_production_pxe.vmlinuz.sig ./ > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    cd $BSROOT/tftpboot
    gpg --verify coreos_production_pxe.vmlinuz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Downloading CoreOS PXE CPIO image ... "
    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$VERSION/coreos_production_pxe_image.cpio.gz || { echo "Failed"; exit 1; }
    rm -f $BSROOT/tftpboot/coreos_production_pxe_image.cpio.gz > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    ln -s ../html/static/$VERSION/coreos_production_pxe_image.cpio.gz ./  > /dev/null 2>&1 || { echo "Failed"; exit 1; }

    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$VERSION/coreos_production_pxe_image.cpio.gz.sig || { echo "Failed"; exit 1; }
    rm -f $BSROOT/tftpboot/coreos_production_pxe_image.cpio.gz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    ln -s ../html/static/$VERSION/coreos_production_pxe_image.cpio.gz.sig ./ > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    gpg --verify coreos_production_pxe_image.cpio.gz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"
}


generate_pxe_config() {
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


build_nvidia_gpu_drivers(){
    printf "Generating CoreOS Nvidia GPU drivers ... "
    mkdir -p $BSROOT/coreos_gpu_drivers
    cd $BSROOT/coreos_gpu_drivers

    bash +x $SEXTANT_DIR/scripts/coreos_gpu/build.sh $cluster_desc_coreos_version $cluster_desc_coreos_channel $cluster_desc_coreos_gpu_drivers_version

    echo "Done"

}


