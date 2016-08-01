package tftp

import (
	//"os/exec"
	"log"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
	//"github.com/topicai/candy"
)

func Tftp_install() {
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
		cmd.Run("yum", "-y", "install", "tftp-server")
	case ubuntu:
		cmd.Run("apt-get", "update")
		cmd.Run("apt-get", "-y", "install", "tftp-hpa")
	}

	// Note that the installation of nginx packages should have
	// created directory /etc/tftp.
	/*candy.WithCreated("/etc/tftp/tftp.conf", func(w io.Writer) {
		_, e := fmt.Fprint(w, Conf(tmpl, c))
		candy.Must(e)
	})*/

	switch dist {
	case ubuntu:
		cmd.Run("service", "tftpd-hpa", "restart")
	case centos:
		cmd.Run("chkconfig", "tftp", "xinetd", "on")
		cmd.Run("service", "xinetd", "restart")
	}

}
