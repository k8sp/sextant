package tftp

import (
	"log"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
)

// Install TFTP service on the bootstrapper server
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
	case ubuntu:
		cmd.Run("apt-get", "update")
		cmd.Run("apt-get", "-y", "install", "tftpd-hpa")
	}

	switch dist {
	case ubuntu:
		cmd.Run("service", "tftpd-hpa", "restart")
	case centos:
		cmd.Run("chkconfig", "tftp", "on")
		cmd.Run("chkconfig", "xinetd", "on")
		cmd.Run("service", "xinetd", "restart")
	}

}
