package clusterdesc

import (
	"io/ioutil"
	"path"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func TestGetMasterIP(t *testing.T) {
	c := &Cluster{}

	clusterDescExample, e := ioutil.ReadFile(path.Join(candy.GoPath(), clusterDescExampleFile))
	candy.Must(e)
	candy.Must(yaml.Unmarshal([]byte(clusterDescExample), c))

	assert.Equal(t,
		c.GetMasterHostname(),
		"00-25-90-c0-f7-80",
	)
}
