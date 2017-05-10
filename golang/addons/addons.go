package main

import (
	"flag"
	"html/template"
	"io"
	"io/ioutil"
	"strings"

	"github.com/k8sp/sextant/golang/clusterdesc"
	"github.com/topicai/candy"
	yaml "gopkg.in/yaml.v2"
)

type addonsConfig struct {
	Bootstrapper        string
	Register            string
	DomainName          string
	IPLow               string
	IPHigh              string
	Netmask             string
	Routers             []string
	NameServers         []string
	UpstreamNameServers []string
	Broadcast           string
	IngressReplicas     int
	Dockerdomain        string
	K8sClusterDNS       string
	EtcdEndpoint        string
	Images              map[string]string
	IngressHostNetwork  bool
	MasterHostname      string
	SetNTP              bool
	DNSMASQLease        string
}

func execute(templateFile string, config *clusterdesc.Cluster, w io.Writer) {
	d, e := ioutil.ReadFile(templateFile)
	candy.Must(e)

	tmpl := template.Must(template.New("").Parse(string(d)))

	ac := addonsConfig{
		Bootstrapper:        config.Bootstrapper,
		Register:            config.Register,
		DomainName:          config.DomainName,
		IPLow:               config.IPLow,
		IPHigh:              config.IPHigh,
		Netmask:             config.Netmask,
		Routers:             config.Routers,
		NameServers:         config.Nameservers,
		UpstreamNameServers: config.UpstreamNameServers,
		Broadcast:           config.Broadcast,
		IngressReplicas:     config.GetIngressReplicas(),
		Dockerdomain:        config.Dockerdomain,
		K8sClusterDNS:       config.K8sClusterDNS,
		EtcdEndpoint:        strings.Split(config.GetEtcdEndpoints(), ",")[0],
		Images:              config.Images,
		IngressHostNetwork:  config.IngressHostNetwork,
		MasterHostname:      config.GetMasterHostname(),
		SetNTP:              config.DNSMASQSetNTP,
		DNSMASQLease:        config.DNSMASQLease,
	}

	candy.Must(tmpl.Execute(w, ac))
}

func main() {
	clusterDescFile := flag.String("cluster-desc-file", "./cluster-desc.yml", "Local copy of cluster description YAML file.")
	templateFile := flag.String("template-file", "./ingress.template", "config file template.")
	configFile := flag.String("config-file", "./ingress.yaml", "config file with yaml")
	flag.Parse()

	d, e := ioutil.ReadFile(*clusterDescFile)
	candy.Must(e)

	c := &clusterdesc.Cluster{
		DNSMASQSetNTP: false,
		DNSMASQLease:  "24h",
	}
	candy.Must(yaml.Unmarshal(d, c))
	candy.WithCreated(*configFile, func(w io.Writer) { execute(*templateFile, c, w) })
}
