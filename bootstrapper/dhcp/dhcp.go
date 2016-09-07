package dhcp

import (
	"fmt"
	"io"
	"log"

	"github.com/k8sp/sextant/bootstrapper/cmd"
	"github.com/k8sp/sextant/config"
	"github.com/topicai/candy"
)

// Install installs and configure DHCP serice on the bootstrapper
// server.
//
// On Ubuntu, we install via apt-get -y install isc-dhcp-server.  On
// CentOS 7, we do yum install -y dhcp.  On both OSes, the
// configuration file is /etc/dhcp/dhcpd.conf.
func Install(tmpl string, c *config.Cluster) {
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
		cmd.Run("yum", "-y", "install", "dhcp")
	case ubuntu:
		cmd.Run("apt-get", "update")
		cmd.Run("apt-get", "-y", "install", "isc-dhcp-server")
	}

	// Note that the installation of DHCP packages should have
	// created directory /etc/dhcp.
	candy.WithCreated("/etc/dhcp/dhcpd.conf", func(w io.Writer) {
		_, e := fmt.Fprint(w, Conf(tmpl, c))
		candy.Must(e)
	})

	switch dist {
	case centos:
		cmd.Run("systemctl", "enable", "dhcpd")
		// Due to a bug of CentOS, systemctl cannot run in
		// Docker containers.  Discussions and the explanation
		// of this bug is at
		// https://github.com/docker/docker/issues/7459.  The
		// current fix
		// https://github.com/docker-library/docs/tree/master/centos#systemd-integration
		// is too complex that I don't want to implement.  So
		// I call Try here.
		cmd.Try("systemctl", "restart", "dhcpd")
	case ubuntu:
		cmd.Run("service", "isc-dhcp-server", "restart")
	}
}
