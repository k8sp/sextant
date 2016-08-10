package main

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"path"
	"testing"

	"gopkg.in/yaml.v2"

	"github.com/k8sp/auto-install/config"
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
)

const (
	tmplFile = "src/github.com/k8sp/auto-install/cloud-config-server/template/cloud-config.template"
	caCrt    = "src/github.com/k8sp/auto-install/cloud-config-server/certgen/testdata/ca.pem"
	caKey    = "src/github.com/k8sp/auto-install/cloud-config-server//testdata/ca-key.pem"
)

func TestRun(t *testing.T) {
	// Run the cloud-config-server in a goroutine.
	ccTmpl, e := ioutil.ReadFile(path.Join(candy.GoPath(), tmplFile))
	candy.Must(e)

	clusterDesc := func() []byte { return []byte(config.ExampleYAML) }
	ccTemplate := func() []byte { return ccTmpl }

	ln, e := net.Listen("tcp", ":0") // OS will allocate a not-in-use port.
	candy.Must(e)

	tmpDir, e := ioutil.TempDir("", "")
	candy.Must(e)
	t.Log("Tls cert tmp path: " + tmpDir)

	go run(clusterDesc, ccTemplate, ln, caCrt, caKey)

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
