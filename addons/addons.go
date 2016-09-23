package main

import (
	"flag"
	"html/template"
	"io"
	"io/ioutil"
	"strings"

	"github.com/k8sp/sextant/clusterdesc"
	"github.com/topicai/candy"
	yaml "gopkg.in/yaml.v2"
)

type addonsConfig struct {
	IngressReplicas int
	Dockerdomain    string
	K8sClusterDNS   string
	EtcdEndpoint    string
}

func execute(templateFile string, config *clusterdesc.Cluster, w io.Writer) error {
	d, e := ioutil.ReadFile(templateFile)
	if e != nil {
		return e
	}
	
	tmpl := template.Must(template.New("").Parse(string(d)))

	ac := addonsConfig{
		IngressReplicas: config.GetIngressReplicas(),
		Dockerdomain:    config.Dockerdomain,
		K8sClusterDNS:   config.K8sClusterDNS,
		EtcdEndpoint:    strings.Split(config.GetEtcdEndpoints(), ",")[0],
	}
	return tmpl.Execute(w, ac)
}

func main() {
	clusterDescFile := flag.String("cluster-desc-file", "./cluster-desc.yml", "Local copy of cluster description YAML file.")
	templateFile := flag.String("template-file", "./ingress.template", "config file template.")
	configFile := flag.String("config-file", "./ingress.yaml", "config file with yaml")
	flag.Parse()

	run(*clusterDescFile, *templateFile, *configFile)
}

func run(clusterDescFile, templateFile, configFile string) {
	d, e := ioutil.ReadFile(clusterDescFile)
	candy.Must(e)
	
	c := &clusterdesc.Cluster{}
	candy.Must(yaml.Unmarshal(d, c))
	// Execute ingress yaml

	candy.WithCreated(configFile, func(w io.Writer) {
		candy.Must(execute(templateFile, c, w))
	})
}
