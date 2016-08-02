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
ExecStart=/usr/bin/skydns -machines=http://10.10.10.201:2379 -addr=0.0.0.0:53 -nameservers=8.8.8.8:53,8.8.4.4:53 -domain=unisound.com.

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
exec /usr/bin/skydns -machines=http://10.10.10.201:2379 -addr=0.0.0.0:53 -nameservers=8.8.8.8:53,8.8.4.4:53 -domain=unisound.com.
end script

pre-start script
end script

pre-stop script
    rm /var/run/skydns.pid
end script
`
)

func TestInstall(t *testing.T) {
	if *indocker {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		switch dist := config.LinuxDistro(); dist {
		case "centos":
			cmd.Run("yum", "-y", "install", "curl", "git", "file")
		case "ubuntu":
			cmd.Run("apt-get", "update")
			cmd.Run("apt-get", "-y", "install", "curl", "git", "file")
		default:
			t.Errorf("Unsupported OS: %s", dist)
		}

		Install("", c)

		file := <-sh.Run("file", "/usr/bin/skydns")
		if !strings.Contains(file, "ELF 64-bit LSB") {
			t.Errorf("Command file cannot stat /usr/bin/skydns, got %v", file)
		}
	}
}
