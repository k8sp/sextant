package template

import (
	"io"
//	"os"
	"text/template"
)

type PerNodeConfig struct {
	IP       string `yaml:"ip"`
	EtcdRole string `yaml:"etcd_role"`
	Hostname string `yaml:"hostname"`
	NicName  string `yaml:"nic_name"`
}

type GlobalConfig struct {
	SSHAuthorizedKeys string `yaml:"ssh_authorized_keys"`
	SSHPrivateKey     string `yaml:"ssh_private_key"`
}

type ExecutionConfig struct {
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
		PerNodeConfig: config.Nodes[mac],
		GlobalConfig:  config.Global,
	}
	return tmpl.Execute(w, ec)
}
