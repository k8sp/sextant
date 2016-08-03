package tftp

import (
	"flag"
	"strings"
	"testing"

	"gopkg.in/yaml.v2"

	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
	"github.com/wangkuiyi/sh"
)

var (
	indocker = flag.Bool("indocker", false, "Tells that the test is running in a Docker container")
)

func TestInstall(t *testing.T) {
	if *indocker {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		Install()

		switch config.LinuxDistro() {
		case "centos":
			l := <-sh.Head(sh.Run("service", "xinetd", "status"), 1)
			if strings.Contains(l, "not running") || !strings.Contains(l, "running") {
				t.Errorf("TFTP service is not running: %s", l)
			}
		case "ubuntu":
			l := <-sh.Head(sh.Run("service", "tftpd-hpa", "status"), 1)
			if strings.Contains(l, "not running") || !strings.Contains(l, "running") {
				t.Errorf("TFTP service is not running: %s", l)
			}
		}

	}
}
