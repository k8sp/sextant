package nginx

import (
	"fmt"
	"io"
	"log"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
)

// Install installs and configure Nginx service on the bootstrapper
// server.
//
// On Ubuntu, we install via apt-get -y install nginx.
// On CentOS 7, we do yum -y install epel-release && yum install -y nginx.
// On both OSes, the configuration file is /etc/nginx/nginx.conf.
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
		cmd.Run("yum", "-y", "install", "epel-release")
		cmd.Run("yum", "-y", "install", "nginx")
	case ubuntu:
		cmd.Run("apt-get", "update")
		cmd.Run("apt-get", "-y", "install", "nginx")
	}

	// Note that the installation of nginx packages should have
	// created directory /etc/nginx.
	candy.WithCreated("/etc/nginx/nginx.conf", func(w io.Writer) {
		_, e := fmt.Fprint(w, Conf(tmpl, c))
		candy.Must(e)
	})

	switch dist {
	case centos:
		cmd.Run("systemctl", "enable", "nginx")
		cmd.Run("systemctl", "daemon-reload")
		// Due to a bug of CentOS, systemctl cannot run in
		// Docker containers.  Discussions and the explanation
		// of this bug is at
		// https://github.com/docker/docker/issues/7459.  The
		// current fix
		// https://github.com/docker-library/docs/tree/master/centos#systemd-integration
		// is too complex that I don't want to implement.  So
		// I call Try here.
		cmd.Try("systemctl", "restart", "nginx")
	case ubuntu:
		cmd.Run("service", "nginx", "restart")
	}
}
