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
		"00-25-90-c0-f7-80=http://10.0.2.21:2380,"+
			"00-25-90-c0-f6-ee=http://10.0.2.22:2380,"+
			"00-25-90-c0-f6-d6=http://00-25-90-c0-f6-d6:2380")
}
