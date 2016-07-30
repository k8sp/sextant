package dhcp

import (
	"fmt"
	"io"
	"log"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
)

// Install installs and configure DHCP serice on the bootstrapper
// server.
//
// On Ubuntu, we install via apt-get -y install isc-dhcp-server.  On
// CentOS 7, we do yum install -y dhcp.  On both OSes, the
// configuration file is /etc/dhcp/dhcpd.conf.
func Install(tmpl string, c *config.Cluster) {
	dist := config.LinuxDistro()
	if dist != "centos" && dist != "ubuntu" {
		log.Panicf("Unsupported OS: %s", dist)
	}

	switch dist {
	case "centos":
		cmd.Run("yum", "-y", "install", "dhcp")
	case "ubuntu":
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
	case "centos":
		cmd.Run("systemctl", "enable", "dhcpd")
		cmd.Run("systemctl", "restart", "dhcpd")
	case "ubuntu":
		cmd.Run("service", "isc-dhcp-server", "restart")
	}
}
