#!/bin/bash

CHANNEL=stable

VERSION=$(curl -s https://$CHANNEL.release.core-os.net/amd64-usr/current/version.txt | grep 'COREOS_VERSION=' | cut -f 2 -d '=')

echo "Detected most recent version:" $VERSION

if [[ ! -f CoreOS_Image_Signing_Key.asc ]]; then 
    curl -s -O https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc
fi
gpg --import --keyid-format LONG CoreOS_Image_Signing_Key.asc

(
    if [[ ! -d tftpboot ]]; then
	mkdir tftpboot
	chmod a+rx tftpboot
    fi
    
    cd tftpboot
    
    wget -c https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe.vmlinuz
    wget -c https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe.vmlinuz.sig
    gpg --verify coreos_production_pxe.vmlinuz.sig || { echo 'gpg verify coreos*.vmlinuz failed' ; exit 1; }
    
    wget -c https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe_image.cpio.gz
    wget -c https://${CHANNEL}.release.core-os.net/amd64-usr/${VERSION}/coreos_production_pxe_image.cpio.gz.sig
    gpg --verify coreos_production_pxe_image.cpio.gz.sig || { echo 'gpg verify coreos*.cpio.gz failed' ; exit 1; }
)

(
    if [[ ! -d www ]]; then
	mkdir www
	chmod a+rx www
    fi
    
    cd www

    if [[ ! -d $VERSION ]]; then
	mkdir $VERSION
    fi
    
    cd $VERSION
    
    wget -c https://$CHANNEL.release.core-os.net/amd64-usr/$VERSION/coreos_production_image.bin.bz2
    wget -c https://$CHANNEL.release.core-os.net/amd64-usr/$VERSION/coreos_production_image.bin.bz2.sig
    gpg --verify coreos_production_image.bin.bz2.sig || { echo 'gpg verify coreos*.bin.bz2 failed' ; exit 1; }
)

echo "All CoreOS related files downloaded and GPG verified."
