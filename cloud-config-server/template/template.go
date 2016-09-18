package template

import (
	"io"
	"io/ioutil"
	"strings"
	"text/template"

	"github.com/k8sp/sextant/cloud-config-server/certgen"
	tpcfg "github.com/k8sp/sextant/config"
	"github.com/topicai/candy"
)

// ExecutionConfig struct config a Coreos's cloud config file which use for installing Coreos in k8s cluster.
type ExecutionConfig struct {
	Hostname                 string
	IP                       string
	CephMonitor              bool
	KubeMaster               bool
	EtcdMember               bool
	Ingress                  bool
	InitialCluster           string
	SSHAuthorizedKeys        string
	EtcdEndpoints            string
	MasterIP                 string
	MasterHostname           string
	BootstrapperIP           string
	CaCrt                    string
	Crt                      string
	Key                      string
	Dockerdomain             string
	K8sClusterDNS            string
	K8sServiceClusterIPRange string
}

// Execute returns the executed cloud-config template for a node with
// given MAC address.
func Execute(tmpl *template.Template, config *tpcfg.Cluster, mac, caKey, caCrt string, w io.Writer) error {
	node := getNodeByMAC(config, mac)
	ca, e := ioutil.ReadFile(caCrt)
	candy.Must(e)

	k, c := certgen.Gen(false, node.Hostname(), caKey, caCrt)
	if node.KubeMaster == true {
		k, c = certgen.Gen(true, node.Hostname(), caKey, caCrt)
	}

	ec := ExecutionConfig{
		Hostname:                 node.Hostname(),
		CephMonitor:              node.CephMonitor,
		KubeMaster:               node.KubeMaster,
		EtcdMember:               node.EtcdMember,
		Ingress:                  node.Ingress,
		InitialCluster:           config.InitialEtcdCluster(),
		SSHAuthorizedKeys:        config.SSHAuthorizedKeys,
		MasterHostname:           config.GetMasterHostname(),
		EtcdEndpoints:            config.GetEtcdEndpoints(),
		BootstrapperIP:           config.Bootstrapper,
		Dockerdomain:             config.Dockerdomain,
		K8sClusterDNS:            config.K8sClusterDNS,
		K8sServiceClusterIPRange: config.K8sServiceClusterIPRange,
		// Mulit-line context in yaml should keep the indent,
		// there is no good idea for templaet package to auto keep the indent so far,
		// so insert 6*whitespace at the begging of every line
		CaCrt: strings.Join(strings.Split(string(ca), "\n"), "\n      "),
		Crt:   strings.Join(strings.Split(string(c), "\n"), "\n      "),
		Key:   strings.Join(strings.Split(string(k), "\n"), "\n      "),
	}
	return tmpl.Execute(w, ec)
}

func getNodeByMAC(c *tpcfg.Cluster, mac string) tpcfg.Node {
	for _, n := range c.Nodes {
		if n.MAC == mac {
			return n
		}
	}
	return tpcfg.Node{MAC: mac, CephMonitor: false, KubeMaster: false, EtcdMember: false}
}
