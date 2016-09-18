package main

import (
	"flag"
	"html/template"
	"io"
	"io/ioutil"
	"path"
	"strings"

	"github.com/k8sp/sextant/config"
	tpcfg "github.com/k8sp/sextant/config"
	"github.com/topicai/candy"
	yaml "gopkg.in/yaml.v2"
)

type addonsConfig struct {
	IngressReplicas int
	Dockerdomain    string
	K8sClusterDNS   string
	EtcdEndpoint    string
}

func execute(templateFile string, config *tpcfg.Cluster, w io.Writer) error {
	d, _ := ioutil.ReadFile(templateFile)
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
	ingressTemplateFile := flag.String("ingress-template-file", "./ingress.template", "ingress config file template.")
	skydnsTempmlateFile := flag.String("skydns-template-file", "./skydns.template", "ingress config file template.")
	dir := flag.String("dir", "./static/", "The directory to serve files from. Default is ./static/")
	flag.Parse()

	run(*clusterDescFile, *dir, *ingressTemplateFile, *skydnsTempmlateFile)
}

func run(clusterDescFile, dir, ingressTemplateFile, skydnsTemplateFile string) {
	d, _ := ioutil.ReadFile(clusterDescFile)
	c := &config.Cluster{}
	candy.Must(yaml.Unmarshal(d, c))
	// Execute ingress yaml
	ingressYaml := path.Join(dir, "ingress.yaml")
	candy.WithCreated(ingressYaml, func(w io.Writer) {
		candy.Must(execute(ingressTemplateFile, c, w))
	})

	// Execute Skydns yaml
	skydnsYaml := path.Join(dir, "skydns.yaml")
	candy.WithCreated(skydnsYaml, func(w io.Writer) {
		candy.Must(execute(skydnsTemplateFile, c, w))
	})
}
