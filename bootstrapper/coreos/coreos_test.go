package coreos

import (
	"testing"

	"gopkg.in/yaml.v2"

	"github.com/k8sp/sextant/bootstrapper/cmd"
	"github.com/k8sp/sextant/bootstrapper/vmtest"
	"github.com/k8sp/sextant/config"
	"github.com/topicai/candy"
)

func TestDownloadBootImage(t *testing.T) {
	if *vmtest.InVM {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		switch dist := config.LinuxDistro(); dist {
		case "centos":
			cmd.Run("yum", "-y", "install", "curl")
		case "ubuntu":
			cmd.Run("apt-get", "update")
			cmd.Run("apt-get", "-y", "install", "curl")
		default:
			t.Errorf("Unsupported OS: %s", dist)
		}

		DownloadBootImage(c)
	}
}
