package dhcp

import (
	"flag"
	"os"
	"testing"

	"gopkg.in/yaml.v2"

	"log"

	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
)

var (
	indocker = flag.Bool("indocker", false,
		"Tells that the test is running in a Docker container by dhcp_test.bash.")
)

func TestInstall(t *testing.T) {
	if *indocker {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		Install("", c)

		if _, err := os.Stat("/etc/dhcp/dhcpd.conf"); os.IsNotExist(err) {
			log.Printf("Failed to install/configure DHCP, /etc/dhcp/dhcpd.conf doesn't exist")
		}
	}
}
