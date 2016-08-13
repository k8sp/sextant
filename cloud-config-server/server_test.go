package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"path"
	"testing"

	"gopkg.in/yaml.v2"

	"github.com/k8sp/auto-install/cloud-config-server/certgen"
	"github.com/k8sp/auto-install/config"
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
)

const (
	tmplFile = "src/github.com/k8sp/auto-install/cloud-config-server/template/cloud-config.template"
)

func TestRun(t *testing.T) {
	out, e := ioutil.TempDir("", "")
	candy.Must(e)
	defer func() {
		if e = os.RemoveAll(out); e != nil {
			log.Printf("Generator.Gen failed deleting %s", out)
		}
	}()
	caKey, caCrt := certgen.GenerateRootCA(out)

	// Run the cloud-config-server in a goroutine.
	ccTmpl, e := ioutil.ReadFile(path.Join(candy.GoPath(), tmplFile))
	candy.Must(e)

	clusterDesc := func() []byte { return []byte(config.ExampleYAML) }
	ccTemplate := func() []byte { return ccTmpl }

	ln, e := net.Listen("tcp", ":0") // OS will allocate a not-in-use port.
	candy.Must(e)

	go run(clusterDesc, ccTemplate, ln, caKey, caCrt)

	// Retrieve a cloud-config file from the in-goroutine server.
	r, e := http.Get(fmt.Sprintf("http://%s/cloud-config/00:25:90:c0:f7:80", ln.Addr()))
	candy.Must(e)

	cc, e := ioutil.ReadAll(r.Body)
	candy.Must(e)
	candy.Must(r.Body.Close())

	// Compare only a small fraction -- the etcd2 initial cluster -- for testing.
	yml := make(map[interface{}]interface{})
	candy.Must(yaml.Unmarshal(cc, yml))
	initialEtcdCluster := yml["coreos"].(map[interface{}]interface{})["etcd2"].(map[interface{}]interface{})["initial-cluster"]

	c := &config.Cluster{}
	candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

	assert.Equal(t, c.InitialEtcdCluster(), initialEtcdCluster)
}
