#!/bin/bash

(
    if [[ ! -d tftpboot ]]; then
	mkdir tftpboot
	chmod a+rx tftpboot
    fi
    
    cd tftpboot

    wget -c https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.zip

    unzip syslinux-6.03.zip bios/core/pxelinux.0
    mv bios/core/pxelinux.0 .
    
    unzip syslinux-6.03.zip bios/com32/elflink/ldlinux/ldlinux.c32
    mv bios/com32/elflink/ldlinux/ldlinux.c32 .
)
