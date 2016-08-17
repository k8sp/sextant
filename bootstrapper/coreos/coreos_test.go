package coreos

import (
	"strings"
	"testing"

	"gopkg.in/yaml.v2"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/bootstrapper/vmtest"
	"github.com/k8sp/auto-install/config"
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
)

func TestVersion(t *testing.T) {
	channel, _ := version("")
	assert.Equal(t, "stable", channel)

	_, alpha := version("alpha")
	_, beta := version("beta")
	_, stable := version("stable")
	assert.True(t, strings.Compare(stable, beta) <= 0)
	assert.True(t, strings.Compare(stable, alpha) <= 0)
}

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
