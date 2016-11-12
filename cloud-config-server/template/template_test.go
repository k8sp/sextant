package template

import (
	"bytes"
	"io"
	"io/ioutil"
	"log"
	"os"
	"testing"
	"text/template"

	"github.com/k8sp/sextant/cloud-config-server/certgen"
	"github.com/k8sp/sextant/clusterdesc"
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func TestExecute(t *testing.T) {
	out, err := ioutil.TempDir("", "")
	candy.Must(err)
	defer func() {
		if e := os.RemoveAll(out); e != nil {
			log.Printf("Generator.Gen failed deleting %s", out)
		}
	}()
	caKey, caCrt := certgen.GenerateRootCA(out)

	config := candy.WithOpened("./cluster-desc.sample.yaml", func(r io.Reader) interface{} {
		b, e := ioutil.ReadAll(r)
		candy.Must(e)

		c := &clusterdesc.Cluster{}
		assert.Nil(t, yaml.Unmarshal(b, &c))
		return c
	}).(*clusterdesc.Cluster)

	tmpl, e := template.ParseFiles("cloud-config.template")
	candy.Must(e)
	var ccTmpl bytes.Buffer
	Execute(tmpl, config, "00:25:90:c0:f7:80", caKey, caCrt, &ccTmpl)
	yml := make(map[interface{}]interface{})
	candy.Must(yaml.Unmarshal(ccTmpl.Bytes(), yml))
	initialEtcdCluster := yml["coreos"].(map[interface{}]interface{})["etcd2"].(map[interface{}]interface{})["initial-cluster-token"]
	assert.Equal(t, initialEtcdCluster, "etcd-cluster-1")
}
