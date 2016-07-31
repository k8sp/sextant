package skydns

import (
	"flag"
	"log"
	"testing"

	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
	"github.com/stretchr/testify/assert"
)

var (
	indocker = flag.Bool("indocker", false,
		"Tells that the test is running in a Docker container.")
)

const (
	serviceContent = `
[Unit]
Description=SkyDNS
After=network.target
Requires=network.target

[Service]
Type=simple
ExecStart=/usr/bin/skydns -machines=http://10.10.10.201:2379 -addr=0.0.0.0:53 -nameservers=8.8.8.8:53,8.8.4.4:53 -domain=unisound.com.

[Install]
WantedBy=multi-user.target
`
)

func TestService(t *testing.T) {
	c := &config.Cluster{}
	candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))
	assert.Equal(t, serviceContent, MakeService("", c))

}

func TestSkyDNS(t *testing.T) {
	if *indocker {
		const (
			centos = "centos"
			ubuntu = "ubuntu"
		)

		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		switch dist := config.LinuxDistro(); dist {
		case centos:
			cmd.Run("yum", "-y", "install", "curl")
			InstallonCentOS("", c)
		case ubuntu:
			cmd.Run("apt-get", "update")
			cmd.Run("apt-get", "-y", "install", "curl")
			InstallonUbuntu("", c)
		default:
			log.Panicf("Unsupported OS: %s", dist)
		}

	}
}
