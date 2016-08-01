package template

import (
	"fmt"
	"io"
	"text/template"

	tptls "github.com/k8sp/auto-install/cloud-config-server/tls"
	tpcfg "github.com/k8sp/auto-install/config"
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
	CertCA            string
	CertAPIServer     string
	CertAPIServerKey  string
	CertWorker        string
	CertWorkerKey     string
}

// Execute returns the executed cloud-config template for a node with
// given MAC address.
func Execute(tmpl *template.Template, config *tpcfg.Cluster, mac string, w io.Writer) error {
	node := getNodeByMAC(config, mac)
	generateCertFiles(node)
	ec := ExecutionConfig{
		Hostname:          mac,
		IP:                node.IP,
		CephMonitor:       node.CephMonitor,
		KubeMaster:        node.KubeMaster,
		EtcdMember:        node.EtcdMember,
		InitialCluster:    config.InitialEtcdCluster(),
		SSHAuthorizedKeys: config.SSHAuthorizedKeys,
		CertCA:            config.CertCA(),
		CertAPIServer:     config.CertAPIServer(node.IP),
		CertAPIServerKey:  config.CertAPIServerKey(node.IP),
		CertWorker:        config.CertWorker(node.IP),
		CertWorkerKey:     config.CertWorkerKey(node.IP),
	}
	return tmpl.Execute(w, ec)
}

func generateCertFiles(node tpcfg.Node) {
	fmt.Printf(node.IP + "\n")
	if node.KubeMaster == true {
		tptls.GenerateMasterCert(node.IP)
	} else {
		tptls.GenerateWorkerCert(node.IP)
	}
}

func getNodeByMAC(c *tpcfg.Cluster, mac string) tpcfg.Node {
	for _, n := range c.Nodes {
		if n.Hostname() == mac {
			return n
		}
	}
	return tpcfg.Node{MAC: "", IP: "", CephMonitor: false, KubeMaster: false, EtcdMember: false}
}
