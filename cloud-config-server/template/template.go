package template

import (
	"io"
	"text/template"
	tpcfg "github.com/k8sp/auto-install/config"
)

type ExecutionConfig struct {
	Hostname string
	IP string
	CephMonitor bool
	KubeMaster bool
	EtcdMember bool
	InitialCluster string
	SSHAuthorizedKeys string
}

// Execute returns the executed cloud-config template for a node with
// given MAC address.
func Execute(tmpl *template.Template, config *tpcfg.Cluster, mac string, w io.Writer) error {
	node := getNodeByMAC(config, mac)
	ec := ExecutionConfig{
		Hostname:	mac,
		IP:		node.IP,
		CephMonitor:	node.CephMonitor,
		KubeMaster:	node.KubeMaster,
		EtcdMember:	node.EtcdMember,
		InitialCluster:	config.InitialEtcdCluster(),
		SSHAuthorizedKeys: config.SSHAuthorizedKeys,
	}
	return tmpl.Execute(w, ec)
}


func getNodeByMAC(c *tpcfg.Cluster, mac string) tpcfg.Node {
	for _, n := range c.Nodes {
		if n.Hostname() == mac {
			return n
		}
	}
	return tpcfg.Node{"", "", false, false, false}
}
