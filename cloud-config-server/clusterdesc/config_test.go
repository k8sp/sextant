package clusterdesc

import (
	"io/ioutil"
	"path"
	"testing"

	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func TestDefaultValues(t *testing.T) {
	c := &Cluster{}
	clusterDescExample, e := ioutil.ReadFile(path.Join(candy.GoPath(), clusterDescExampleFile))
	candy.Must(e)
	candy.Must(yaml.Unmarshal([]byte(clusterDescExample), c))

}
