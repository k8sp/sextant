// cloud-config-server starts an HTTP server, which can be accessed
// via URLs in the form of
//
//   http://<addr:port>?mac=aa:bb:cc:dd:ee:ff
//
// and returns the cloud-config YAML file specificially tailored for
// the node whose primary NIC's MAC address matches that specified in
// above URL.
package main

import (
	"bytes"
	"errors"
	"flag"
	"github.com/golang/glog"
	"github.com/k8sp/sextant/golang/certgen"
	"github.com/k8sp/sextant/golang/clusterdesc"
	cctemplate "github.com/k8sp/sextant/golang/template"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"os"
	"strings"
)

func main() {
	clusterDesc := flag.String("cluster-desc", "./cluster-desc.yml", "Configurations for a k8s cluster.")
	ccTemplateDir := flag.String("cloud-config-dir", "./cloud-config.template", "cloud-config file template.")
	flag.Parse()

	glog.Info("Checking %s ...", *clusterDesc)
	err := validation(*clusterDesc, *ccTemplateDir)
	if err != nil {
		glog.Info("Failed: \n" + err.Error())
		os.Exit(1)
	}
	glog.Info("Successed!")
	os.Exit(0)
}

// Validate cluster-desc.yaml and check the generated cloud-config file format.
func validation(clusterDescFile string, ccTemplateDir string) error {
	clusterDesc, err := ioutil.ReadFile(clusterDescFile)
	candy.Must(err)
	_, direrr := os.Stat(ccTemplateDir)
	if os.IsNotExist(direrr) {
		return direrr
	}

	c := &clusterdesc.Cluster{}
	// validate cluster-desc format
	err = yaml.Unmarshal(clusterDesc, c)
	if err != nil {
		return errors.New("cluster-desc file formate failed: " + err.Error())
	}

	// flannel backend only support host-gw and udp for now
	if c.FlannelBackend != "host-gw" && c.FlannelBackend != "udp" && c.FlannelBackend != "vxlan" {
		return errors.New("Flannl backend should be host-gw or udp.")
	}

	// Inlucde one master and one etcd member at least
	countEtcdMember := 0
	countKubeMaster := 0
	for _, node := range c.Nodes {
		if node.EtcdMember {
			countEtcdMember++
		}
		if node.KubeMaster {
			countKubeMaster++
		}
	}
	if countEtcdMember == 0 || countKubeMaster == 0 {
		return errors.New("Cluster description yaml should include one master and one etcd member at least.")
	}

	if len(c.SSHAuthorizedKeys) == 0 {
		return errors.New("Cluster description yaml should include one ssh key.")
	}

	caKey := "./tmp_ca.key"
	caCrt := "./tmp_ca.crt"
	certgen.GenerateCA(caKey, caCrt)
	var ccTmplBuffer bytes.Buffer
	for _, n := range c.Nodes {
		mac := n.Mac()
		err = cctemplate.Execute(&ccTmplBuffer, mac, "cc-template", ccTemplateDir, clusterDescFile, caKey, caCrt)
		if err != nil {
			return errors.New("Generate cloud-config failed with mac: " + mac + "\n" + err.Error())
		}

		yml := make(map[interface{}]interface{})
		err = yaml.Unmarshal(ccTmplBuffer.Bytes(), yml)
		if err != nil {
			return errors.New("Generate cloud-config format failed with mac: " + mac + "\n" + err.Error())
		}
		ccTmplBuffer.Reset()
		// check generated cloud-config in yaml format
		for _, wfunit := range yml["write_files"].([]interface{}) {
			fn := wfunit.(map[interface{}]interface{})["path"].(string)
			fcontent := wfunit.(map[interface{}]interface{})["content"].(string)
			if strings.HasSuffix(fn, "ca.pem") && fcontent == "" {
				return errors.New("cloud-config has no CA contents")
			}
		}
	}
	return nil
}
