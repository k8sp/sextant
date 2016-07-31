package nginx

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
	indocker = flag.Bool("indocker", false,
		"Tells that the test is running in a Docker container by nginx.bash.")
)

func TestInstall(t *testing.T) {
	if *indocker {
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
