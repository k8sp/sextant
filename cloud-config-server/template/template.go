package template

import (
	"io"
	"text/template"
)

type PerNodeConfig struct {
	IP       string `yaml:"ip"`
	CephRole string `yaml:"ceph_role"`
	K8sRole  string `yaml:"k8s_role"`
}

type GlobalConfig struct {
	InitialCluster    string `yaml:"initial_cluster"`
	SSHAuthorizedKeys string `yaml:"ssh_authorized_keys"`
	SSHPrivateKey     string `yaml:"ssh_private_key"`
}

type ExecutionConfig struct {
	Hostname string
	PerNodeConfig
	GlobalConfig
}

type Config struct {
	Nodes  map[string]PerNodeConfig
	Global GlobalConfig
}

// Execute returns the executed cloud-config template for a node with
// given MAC address.
func Execute(tmpl *template.Template, config *Config, mac string, w io.Writer) error {
	ec := ExecutionConfig{
		Hostname:      mac,
		PerNodeConfig: config.Nodes[mac],
		GlobalConfig:  config.Global,
	}
	return tmpl.Execute(w, ec)
}
