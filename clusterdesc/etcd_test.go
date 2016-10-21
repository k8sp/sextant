package clusterdesc

import (
	"fmt"
	"io/ioutil"
	"path"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

const (
	clusterDescExampleFile = "src/github.com/k8sp/sextant/template/cluster-desc.samlple.yaml"
)

func TestInitialEtcdCluster(t *testing.T) {
	c := &Cluster{}
	clusterDescExample, e := ioutil.ReadFile(path.Join(candy.GoPath(), clusterDescExampleFile))
	candy.Must(e)
	candy.Must(yaml.Unmarshal([]byte(clusterDescExample), c))
	assert.Equal(t,
		c.InitialEtcdCluster(),
		"00-25-90-c0-f7-80=http://00-25-90-c0-f7-80:2380,"+
			"00-25-90-c0-f6-ee=http://00-25-90-c0-f6-ee:2380,"+
			"00-25-90-c0-f6-d6=http://00-25-90-c0-f6-d6:2380")
}

func TestGetEtcdMachines(t *testing.T) {
	c := &Cluster{}
	clusterDescExample, e := ioutil.ReadFile(path.Join(candy.GoPath(), clusterDescExampleFile))
	candy.Must(e)
	candy.Must(yaml.Unmarshal([]byte(clusterDescExample), c))
	assert.Equal(t, c.GetEtcdMachines(),
		"http://00-25-90-c0-f7-80:2379,http://00-25-90-c0-f6-ee:2379,http://00-25-90-c0-f6-d6:2379")
}

func TestSelectNodes(t *testing.T) {
	c := &Cluster{}
	clusterDescExample, e := ioutil.ReadFile(path.Join(candy.GoPath(), clusterDescExampleFile))
	candy.Must(e)
	candy.Must(yaml.Unmarshal([]byte(clusterDescExample), c))
	ret := c.SelectNodes(func(n *Node) string {
		if n.KubeMaster && len(n.Hostname()) > 0 {
			return fmt.Sprintf("http://%s", n.Hostname())
		}
		return ""
	})
	assert.Equal(t, ret, "http://00-25-90-c0-f7-80")
}
