package initcoreos

import (
	"strings"
	"testing"

	yaml "gopkg.in/yaml.v2"

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
	assert.True(t, strings.Compare(beta, alpha) <= 0)
}

func TestDownloadBootImage(t *testing.T) {
	c := &config.Cluster{}
	candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))
	e := DownloadBootImage(c)
	assert.Nil(t, e)
}
