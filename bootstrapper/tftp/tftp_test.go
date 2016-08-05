package tftp

import (
	"strings"
	"testing"

	"gopkg.in/yaml.v2"

	"github.com/k8sp/auto-install/bootstrapper/vmtest"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
	"github.com/wangkuiyi/sh"
)


func TestInstall(t *testing.T) {
	if *vmtest.InVM {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		Install()

		switch config.LinuxDistro() {
		case "centos":
			l := <-sh.Head(sh.Run("service", "tftp", "status"), 1)
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
