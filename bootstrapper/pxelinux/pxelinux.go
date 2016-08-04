package pxelinux

import (
	"log"

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
		cmd.Run("yum", "-y", "install", "syslinux")
		cmd.Run("cp", "/usr/share/syslinux/pxelinux.0", "/var/lib/tftpboot/")
	case ubuntu:
		cmd.Run("apt-get", "update")
		cmd.Run("apt-get", "-y", "install", "syslinux")
		cmd.Run("cp", "/usr/lib/syslinux/pxelinux.0", "/var/lib/tftpboot/")
	}

}
