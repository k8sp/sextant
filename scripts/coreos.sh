#!/usr/bin/env bash


check_coreos_version () {
    printf "Checking the CoreOS version ... "
    VERSION=$(curl -s https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$cluster_desc_coreos_version/version.txt | grep 'COREOS_VERSION=' | cut -f 2 -d '=')
    if [[ $VERSION == "" ]]; then
        echo "Failed"; exit 1;
    fi
    echo "Done with coreos channel: " $cluster_desc_coreos_channel "version: " $VERSION
}

update_coreos_images() {
  printf "Updating CoreOS images ... "
if [[ ! -d $BSROOT/html/static/$VERSION ]]; then
    mkdir -p $BSROOT/html/static/$VERSION
fi

wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$cluster_desc_coreos_version/version.txt
wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$cluster_desc_coreos_version/coreos_production_image.bin.bz2 || { echo "Failed"; exit 1; }
wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://$cluster_desc_coreos_channel.release.core-os.net/amd64-usr/$cluster_desc_coreos_version/coreos_production_image.bin.bz2.sig || { echo "Failed"; exit 1; }
cd $BSROOT/html/static/$VERSION
gpg --verify coreos_production_image.bin.bz2.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
cd $BSROOT/html/static
# Never change 'current' to 'current/', I beg you.
rm -rf current > /dev/null 2>&1
ln -sf ./$VERSION current || { echo "Failed"; exit 1; }
echo "Done"
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

acquire_specify_version() {
  # Fetch release binary tarball from github accroding to the versions
  # defined in "cluster-desc.yml"
  hyperkube_version=`grep "hyperkube:" $CLUSTER_DESC | grep -o '".*hyperkube.*:.*"' | sed 's/".*://; s/"//'`
  printf "Downloading and kubelet and kubectl of release ${hyperkube_version} ... "
  wget --quiet -c -N -O $BSROOT/html/static/kubelet https://storage.googleapis.com/kubernetes-release/release/$hyperkube_version/bin/linux/amd64/kubelet
  chmod +x $BSROOT/html/static/kubelet
  echo "Done"

  # setup-network-environment will fetch the default system IP infomation
  # when using cloud-config file to initiate a kubernetes cluster node
  printf "Downloading setup-network-environment file ... "
  wget --quiet -c -N -O $BSROOT/html/static/setup-network-environment-1.0.1 https://github.com/kelseyhightower/setup-network-environment/releases/download/1.0.1/setup-network-environment || { echo "Failed"; exit 1; }
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


build_coreos_nvidia_gpu_drivers(){
    printf "Generating CoreOS Nvidia GPU drivers ... "
    bash +x $SEXTANT_DIR/scripts/coreos_gpu/build.sh $SEXTANT_DIR/scripts/coreos_gpu $BSROOT/html/static/coreos_gpu_drivers \
        $cluster_desc_gpu_drivers_version $cluster_desc_coreos_channel $cluster_desc_coreos_version \
        ||  { echo "Failed"; exit 1; }

    cp $SEXTANT_DIR/scripts/coreos_gpu/setup_gpu.sh $BSROOT/html/static/coreos_gpu_drivers || { echo "Failed"; exit 1; }

    echo "Done"

}
