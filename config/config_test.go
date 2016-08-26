package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func TestDefaultValues(t *testing.T) {
	c := &Cluster{}
	candy.Must(yaml.Unmarshal([]byte(ExampleYAML), c))

	assert.False(t, c.Nodes[1].KubeMaster)
	assert.False(t, c.Nodes[2].KubeMaster)
	assert.False(t, c.Nodes[3].KubeMaster)
	assert.False(t, c.Nodes[3].EtcdMember)
	assert.False(t, c.Nodes[3].CephMonitor)
}
