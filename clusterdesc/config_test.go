package clusterdesc

import (
	"io/ioutil"
	"path"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func TestDefaultValues(t *testing.T) {
	c := &Cluster{}
	clusterDescExample, e := ioutil.ReadFile(path.Join(candy.GoPath(), clusterDescExampleFile))
	candy.Must(e)
	candy.Must(yaml.Unmarshal([]byte(clusterDescExample), c))

	assert.False(t, c.Nodes[1].KubeMaster)
	assert.False(t, c.Nodes[2].KubeMaster)
	assert.False(t, c.Nodes[3].KubeMaster)
	assert.False(t, c.Nodes[3].IngressLabel)
	assert.False(t, c.Nodes[3].CephMonitor)
}
