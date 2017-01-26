package clusterdesc

import (
	"io/ioutil"
	"path"
	"testing"

	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

const (
	clusterDescExampleFile = "src/github.com/k8sp/sextant/golang/template/cluster-desc.sample.yaml"
)

func TestInitialEtcdCluster(t *testing.T) {
	c := &Cluster{}
	clusterDescExample, e := ioutil.ReadFile(path.Join(candy.GoPath(), clusterDescExampleFile))
	candy.Must(e)
	candy.Must(yaml.Unmarshal([]byte(clusterDescExample), c))
}

func TestGetEtcdMachines(t *testing.T) {
	c := &Cluster{}
	clusterDescExample, e := ioutil.ReadFile(path.Join(candy.GoPath(), clusterDescExampleFile))
	candy.Must(e)
	candy.Must(yaml.Unmarshal([]byte(clusterDescExample), c))
}
