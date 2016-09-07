package nginx

import (
	"strings"
	"testing"

	"gopkg.in/yaml.v2"

	"github.com/k8sp/sextant/bootstrapper/vmtest"
	"github.com/k8sp/sextant/config"
	"github.com/topicai/candy"
	"github.com/wangkuiyi/sh"
)

func TestInstall(t *testing.T) {
	if *vmtest.InVM {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		Install("", c)

		switch config.LinuxDistro() {
		case "centos":
			// A bug
			// https://github.com/docker/docker/issues/7459
			// prevents us from starting nginx service in a CentOS docker container.
		case "ubuntu":
			l := <-sh.Head(sh.Run("service", "nginx", "status"), 1)
			if strings.Contains(l, "not running") || !strings.Contains(l, "running") {
				t.Errorf("nginx service is not running: %s", l)
			}
		}

	}
}
