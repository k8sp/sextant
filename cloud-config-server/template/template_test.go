package template

import (
	"bytes"
	"fmt"
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
	fmt.Println(ccTmpl.String())
	candy.Must(yaml.Unmarshal(ccTmpl.Bytes(), yml))
	switch i := config.OSName; i {
	case "CoreOS":
		initialEtcdCluster := yml["coreos"].(map[interface{}]interface{})["etcd2"].(map[interface{}]interface{})["initial-cluster-token"]
		assert.Equal(t, initialEtcdCluster, "etcd-cluster-1")
	case "CentOS":
		//array_path := []string{"/etc/system/systemd/etcd2.service", "/etc/system/systemd/flanneld.service", "/etc/system/systemd/setup-network-environment.service", "/etc/system/systemd/ceph-mon.service", "/etc/system/systemd/ceph-osd.service",
		//	"/etc/system/systemd/kube-addons.service", "/etc/system/systemd/kubelet.service"}
		//silce := make([]string, 100)
		for _, fileinfo := range yml["write_files"].([]interface{}) {
			fmt.Println("########")
			m := fileinfo.(map[interface{}]interface{})["path"]
			//	silce = append(silce, string(m))
			fmt.Println(m)
			//	for o, _ := range array_path {
			//		fmt.Println("-------", array_path[o], "=====")
			//assert.Equal(t, )
			//	}
		}
	}

}
