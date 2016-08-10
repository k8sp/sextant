package template

import (
	tpcfg "github.com/k8sp/auto-install/config"
	"io"
	"text/template"
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
	EtcdEndpoints	  string
	MasterIP	  string
	BootstrapperIP    string
}

// Execute returns the executed cloud-config template for a node with
// given MAC address.
func Execute(tmpl *template.Template, config *tpcfg.Cluster, mac string, w io.Writer) error {
	node := getNodeByMAC(config, mac)
	ec := ExecutionConfig{
		Hostname:          mac,
		IP:                node.IP,
		CephMonitor:       node.CephMonitor,
		KubeMaster:        node.KubeMaster,
		EtcdMember:        node.EtcdMember,
		InitialCluster:    config.InitialEtcdCluster(),
		SSHAuthorizedKeys: config.SSHAuthorizedKeys,
		MasterIP:	   config.GetMasterIP(),
	        EtcdEndpoints:     config.GetEtcdEndpoints(),
		BootstrapperIP:    config.Bootstrapper,
	}
	return tmpl.Execute(w, ec)
}

func getNodeByMAC(c *tpcfg.Cluster, mac string) tpcfg.Node {
	for _, n := range c.Nodes {
		if n.Hostname() == mac {
			return n
		}
	}
	return tpcfg.Node{MAC: "", IP: "", CephMonitor: false, KubeMaster: false, EtcdMember: false}
}
