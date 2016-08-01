package dhcp

import (
	"flag"
	"os"
	"strings"
	"testing"

	"gopkg.in/yaml.v2"

	"log"

	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
	"github.com/wangkuiyi/sh"
)

var (
	indocker = flag.Bool("indocker", false, "Tells that the test is running in a Docker container.")
)

func TestInstall(t *testing.T) {
	if *indocker {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		Install("", c)

		if _, err := os.Stat("/etc/dhcp/dhcpd.conf"); os.IsNotExist(err) {
			log.Printf("Failed to install/configure DHCP, /etc/dhcp/dhcpd.conf doesn't exist")
		}

		switch config.LinuxDistro() {
		case "centos":
			// A bug
			// https://github.com/docker/docker/issues/7459
			// prevents us from starting DHCP service in a CentOS docker container.
		case "ubuntu":
			l := <-sh.Head(sh.Run("service", "isc-dhcp-server", "status"), 1)
			if strings.Contains(l, "not running") || !strings.Contains(l, "running") {
				t.Errorf("DHCP service is not running: %s", l)
			}
		}

	}
}
