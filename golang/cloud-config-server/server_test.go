package main

import (
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/gorilla/mux"
	"github.com/k8sp/sextant/golang/certgen"
	"github.com/k8sp/sextant/golang/clusterdesc"
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

const (
	tmplFile               = "src/github.com/k8sp/sextant/golang/template/cloud-config.template"
	templateDir            = "../template/templatefiles"
	clusterDescExampleFile = "../template/cluster-desc.sample.yaml"
	loadTimeout            = 15 * time.Second
)

func TestCloudConfigHandler(t *testing.T) {
	// generate temp ca files for unitest and delete it when exit
	out, e := ioutil.TempDir("", "")
	candy.Must(e)
	defer func() {
		if e = os.RemoveAll(out); e != nil {
			log.Printf("Generator.Gen failed deleting %s", out)
		}
	}()
	caKey, caCrt := certgen.GenerateRootCA(out)
	// load ClusterDesc
	config := candy.WithOpened(clusterDescExampleFile, func(r io.Reader) interface{} {
		b, e := ioutil.ReadAll(r)
		candy.Must(e)

		c := &clusterdesc.Cluster{}
		assert.Nil(t, yaml.Unmarshal(b, &c))
		return c
	}).(*clusterdesc.Cluster)
	// test HTTP handler directly
	rr := httptest.NewRecorder()
	req, err := http.NewRequest("GET", "/cloud-config/00:25:90:c0:f7:80", nil)
	if err != nil {
		t.Fatal(err)
	}
	// use mux router.ServeHTTP to test handlers
	// TODO: put route setups in a common function
	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/cloud-config/{mac}",
		makeCloudConfigHandler(clusterDescExampleFile, templateDir, caKey, caCrt))
	router.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	if rr.Body.String() != "" {
		// Compare only a small fraction -- the etcd2 initial cluster -- for testing.
		yml := make(map[interface{}]interface{})
		candy.Must(yaml.Unmarshal(rr.Body.Bytes(), yml))
		switch i := config.OSName; i {
		case "CoreOS":
			initialEtcdCluster := yml["coreos"].(map[interface{}]interface{})["etcd2"].(map[interface{}]interface{})["initial-cluster"]
			assert.Equal(t, config.InitialEtcdCluster(), initialEtcdCluster)
		case "CentOS":
			for _, fileinfo := range yml["write_files"].([]interface{}) {
				m := fileinfo.(map[interface{}]interface{})["path"]
				if m == "/etc/systemd/system/setup-network-environment.service" {
					assert.Equal(t, m, "/etc/systemd/system/setup-network-environment.service")
				}
			}
		}
	} else {
		t.Errorf("cloud-config empty.")
	}
}
