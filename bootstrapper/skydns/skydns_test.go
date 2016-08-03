package skydns

import (
	"flag"
	"strings"
	"testing"

	"github.com/topicai/candy"
	"github.com/wangkuiyi/sh"
	"gopkg.in/yaml.v2"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
	"github.com/stretchr/testify/assert"
)

var (
	indocker = flag.Bool("indocker", false, "Tells that the test is running in a Docker container.")
)

const (
	systemdContent = `
[Unit]
Description=SkyDNS
After=network.target
Requires=network.target

[Service]
Type=simple
ExecStart=/usr/bin/skydns -machines=http://172.17.0.10:2379,http://172.17.0.11:2379 -addr=0.0.0.0:53 -nameservers=8.8.8.8:53,8.8.4.4:53 -domain=unisound.com.

[Install]
WantedBy=multi-user.target
`
	upstartContent = `
description "SkyDNS service"

start on runlevel [2345]
stop on runlevel [^2345]

respawn
respawn limit 20 3

script
echo $$ > /var/run/skydns.pid
exec /usr/bin/skydns -machines=http://172.17.0.10:2379,http://172.17.0.11:2379 -addr=0.0.0.0:53 -nameservers=8.8.8.8:53,8.8.4.4:53 -domain=unisound.com.
end script

pre-start script
end script

pre-stop script
    rm /var/run/skydns.pid
end script
`
)

func TestServiceUnit(t *testing.T) {
	c := &config.Cluster{}
	candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))
	assert.Equal(t, systemdContent, serviceUnit("centos", "", c))
	assert.Equal(t, upstartContent, serviceUnit("ubuntu", "", c))
}

func TestInstall(t *testing.T) {
	if *indocker {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		dist := config.LinuxDistro()
		switch dist {
		case "centos":
			cmd.Run("yum", "-y", "install", "curl", "git")
		case "ubuntu":
			cmd.Run("apt-get", "update")
			cmd.Run("apt-get", "-y", "install", "curl", "git")
		default:
			t.Errorf("Unsupported OS: %s", dist)
		}

		Install("", c)

		switch dist {
		case "centos":
			status := <-sh.Run("systemctl", "is-active", "skydns")
			if !strings.Contains(status, "active") {
				t.Errorf("Can not start skydns service, %s", status)
			}
		case "ubuntu":
			status := <-sh.Run("service", "skydns", "status")
			if !strings.Contains(status, "running") {
				t.Errorf("Can not start skydns service, %s", status)
			}
		}

	}
}
