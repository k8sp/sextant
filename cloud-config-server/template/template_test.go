package template

import (
	"bytes"
	"io"
	"io/ioutil"
	"path"
	"testing"
	"text/template"

	tpcfg "github.com/k8sp/auto-install/config"
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

const (
	caCrt = "src/github.com/k8sp/auto-install/cloud-config-server/certgen/testdata/ca.crt"
	caKey = "src/github.com/k8sp/auto-install/cloud-config-server/certgen/testdata/ca.key"
)

func TestExecute(t *testing.T) {

	config := candy.WithOpened("./unisound-ailab/build_config.yml", func(r io.Reader) interface{} {
		b, e := ioutil.ReadAll(r)
		candy.Must(e)

		c := &tpcfg.Cluster{}
		assert.Nil(t, yaml.Unmarshal(b, &c))
		return c
	}).(*tpcfg.Cluster)

	tmpl, e := template.ParseFiles("cloud-config.template")
	candy.Must(e)
	var ccTmpl bytes.Buffer
	Execute(tmpl, config, "00-25-90-c0-f6-ee", path.Join(candy.GoPath(), caCrt), path.Join(candy.GoPath(), caKey), &ccTmpl)
	yml := make(map[interface{}]interface{})
	candy.Must(yaml.Unmarshal(ccTmpl.Bytes(), yml))

	initialEtcdCluster := yml["coreos"].(map[interface{}]interface{})["etcd2"].(map[interface{}]interface{})["initial-cluster-token"]
	assert.Equal(t, initialEtcdCluster, "etcd-cluster-1")
}
