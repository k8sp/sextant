package main

import (
	"bytes"
	"io"
	"io/ioutil"
	"testing"

	tpcfg "github.com/k8sp/sextant/golang/clusterdesc"
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	yaml "gopkg.in/yaml.v2"
)

func TestExecute(t *testing.T) {
	config := candy.WithOpened("../template/cluster-desc.sample.yaml", func(r io.Reader) interface{} {
		b, e := ioutil.ReadAll(r)
		candy.Must(e)

		c := &tpcfg.Cluster{}
		assert.Nil(t, yaml.Unmarshal(b, &c))
		return c
	}).(*tpcfg.Cluster)

	var ccTmpl bytes.Buffer
	execute("./template/ingress.template", config, &ccTmpl)
	yml := make(map[interface{}]interface{})
	candy.Must(yaml.Unmarshal(ccTmpl.Bytes(), yml))

	initialEtcdCluster := yml["metadata"].(map[interface{}]interface{})["name"]
	assert.Equal(t, initialEtcdCluster, "nginx-ingress-controller-v1")
}
