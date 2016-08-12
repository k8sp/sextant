package template

import (
	"io"
	"io/ioutil"
	"strings"
	"text/template"

	"github.com/k8sp/auto-install/cloud-config-server/certgen"
	tpcfg "github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
)

// ExecutionConfig struct config a Coreos's cloud config file which use for installing Coreos in k8s cluster.
type ExecutionConfig struct {
	Hostname          string
	IP                string
	CephMonitor       bool
	KubeMaster        bool
	EtcdMember        bool
	InitialCluster    string
	SSHAuthorizedKeys string
	EtcdEndpoints     string
	MasterIP          string
	BootstrapperIP    string
	CaCrt             string
	Crt               string
	Key               string
}

// Execute returns the executed cloud-config template for a node with
// given MAC address.
func Execute(tmpl *template.Template, config *tpcfg.Cluster, mac, caCrt, caKey string, w io.Writer) error {
	node := getNodeByMAC(config, mac)
	ca, e := ioutil.ReadFile(caCrt)
	candy.Must(e)

	k, c := certgen.Gen(false, node.Hostname(), caCrt, caKey)
	if node.KubeMaster == true {
		k, c = certgen.Gen(true, node.Hostname(), caCrt, caKey)
	}

	ec := ExecutionConfig{
		Hostname:          mac,
		IP:                node.IP,
		CephMonitor:       node.CephMonitor,
		KubeMaster:        node.KubeMaster,
		EtcdMember:        node.EtcdMember,
		InitialCluster:    config.InitialEtcdCluster(),
		SSHAuthorizedKeys: config.SSHAuthorizedKeys,
		MasterIP:          config.GetMasterIP(),
		EtcdEndpoints:     config.GetEtcdEndpoints(),
		BootstrapperIP:    config.Bootstrapper,
		CaCrt:             strings.Join(strings.Split(string(ca), "\n"), "\n      "),
		Crt:               strings.Join(strings.Split(string(c), "\n"), "\n      "),
		Key:               strings.Join(strings.Split(string(k), "\n"), "\n      "),
	}
	return tmpl.Execute(w, ec)
}

func getNodeByMAC(c *tpcfg.Cluster, mac string) tpcfg.Node {
	for _, n := range c.Nodes {
		if n.Hostname() == mac {
			return n
		}
	}
	return tpcfg.Node{MAC: mac, IP: "", CephMonitor: false, KubeMaster: false, EtcdMember: false}
}
