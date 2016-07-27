package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func TestInitialEtcdCluster(t *testing.T) {
	c := &Cluster{}
	candy.Must(yaml.Unmarshal([]byte(testConfig), c))
	assert.Equal(t, c.InitialEtcdCluster(),
		"00-25-90-C0-F7-80=http://10.10.10.201:2380,00-25-90-C0-F6-EE=http://10.10.10.202:2380,00-25-90-C0-F6-D6=http://00-25-90-C0-F6-D6:2380")
}
