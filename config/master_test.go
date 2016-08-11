package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func TestGetMasterIP(t *testing.T) {
	c := &Cluster{}
	candy.Must(yaml.Unmarshal([]byte(ExampleYAML), c))
	assert.Equal(t,
		c.GetMasterIP(),
		"10.0.2.21",
		)
}
