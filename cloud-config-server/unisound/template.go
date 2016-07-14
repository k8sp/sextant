package unisound

import (
	"io"
	"text/template"
)

type GlobalConfig struct {
	InitialCluster    string `yaml:"initial_cluster"`
	SSHAuthorizedKeys string `yaml:"ssh_authorized_keys"`
	SSHPrivateKey     string `yaml:"ssh_private_key"`
}

type ExecutionConfig struct {
	IP string
	Hostname string
	GlobalConfig
}

type Config struct {
	Nodes  map[string]string
	Global GlobalConfig
}

// Execute returns the executed cloud-config template for a node with
// given MAC address.
func Execute(tmpl *template.Template, config *Config, mac string, w io.Writer) error {
	ec := ExecutionConfig{
		IP:            config.Nodes[mac],
		Hostname:      mac,
		GlobalConfig:  config.Global,
	}
	return tmpl.Execute(w, ec)
}
