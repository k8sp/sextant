package pxelinux

import (
	"log"
	"fmt"
        "io/ioutil"
	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
)

//Install pxelinux
func Install() {
	const (
		centos = "centos"
		ubuntu = "ubuntu"
	)

	dist := config.LinuxDistro()
	if dist != centos && dist != ubuntu {
		log.Panicf("Unsupported OS: %s", dist)
	}

	switch dist {
	case centos:
		cmd.Run("yum", "-y", "install", "xinetd")
		cmd.Run("yum", "-y", "install", "tftp-server")
		cmd.Run("yum", "-y", "install", "syslinux")
		cmd.Run("cp", "/usr/share/syslinux/pxelinux.0", "/var/lib/tftpboot/")
		//cmd.Run("cp", "/usr/share/syslinux/modules/bios/ldlinux.c32", "/var/lib/tftpboot/")
                cmd.Run("mkdir", "/var/lib/tftpboot/pxelinux.cfg")
 
                var para="default coreos\n\nlabel coreos\n\tkernel coreos_production_pxe.vmlinuz\n\tappend initrd=coreos_production_pxe_image.cpio.gz cloud-config-url=10.0.2.15/install-coreos.sh"
                fmt.Printf(para)
                ioutil.WriteFile("/var/lib/tftpboot/pxelinux.cfg/default",[]byte(para), 0777)


	case ubuntu:
		cmd.Run("apt-get", "update")
		cmd.Run("apt-get", "-y", "install", "tftpd-hpa")
		cmd.Run("apt-get", "-y", "install", "syslinux")
		cmd.Run("cp", "/usr/lib/syslinux/pxelinux.0", "/var/lib/tftpboot/")
	        //cmd.Run("cp", "/usr/lib/syslinux/modules/bios/ldlinux.c32", "/var/lib/tftpboot/")
		cmd.Run("mkdir", "/var/lib/tftpboot/pxelinux.cfg")
 
		var para="default coreos\n\nlabel coreos\n\tkernel coreos_production_pxe.vmlinuz\n\tappend initrd=coreos_production_pxe_image.cpio.gz cloud-config-url=10.0.2.15/install-coreos.sh"
		fmt.Printf(para)
	        ioutil.WriteFile("/var/lib/tftpboot/pxelinux.cfg/default",[]byte(para), 0777)
	}

	switch dist {
	case ubuntu:
		cmd.Run("service", "tftpd-hpa", "restart")
	case centos:
		cmd.Run("systemctl", "restart", "xinetd")
		cmd.Run("systemctl", "restart", "tftp")
	}


}
