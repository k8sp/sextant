package main

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"path"
	"testing"

	"gopkg.in/yaml.v2"

	"github.com/k8sp/auto-install/cloud-config-server/tls"
	"github.com/k8sp/auto-install/config"
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
)

const (
	tmplFile = "src/github.com/k8sp/auto-install/cloud-config-server/template/cloud-config.template"
	ca       = "src/github.com/k8sp/auto-install/cloud-config-server/tls/data/ca.pem"
	caKey    = "src/github.com/k8sp/auto-install/cloud-config-server/tls/data/ca-key.pem"
)

func TestRun(t *testing.T) {
	// Run the cloud-config-server in a goroutine.
	ccTmpl, e := ioutil.ReadFile(path.Join(candy.GoPath(), tmplFile))
	candy.Must(e)

	ccTemplate := func() string { return string(ccTmpl) }
	clusterDesc := func() []byte { return []byte(config.ExampleYAML) }

	ln, e := net.Listen("tcp", ":0") // OS will allocate a not-in-use port.
	candy.Must(e)

	tls := tls.Tls{CAPem: path.Join(candy.GoPath(), ca), CAKeyPem: path.Join(candy.GoPath(), caKey)}

	go run(clusterDesc, ccTemplate, ln, tls)

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
