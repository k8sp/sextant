package clusterdesc

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
		c.GetMasterHostname(),
		"00-25-90-c0-f7-80",
	)
}
