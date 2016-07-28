package config

import (
	"bytes"
	"html/template"
	"strings"

	"github.com/topicai/candy"
)

// DHCPConf executes a template with a Cluster variable to generate
// /etc/dhcpd/dhcp.conf.
func DHCPConf(tf string, c *Cluster) string {
	tmpl := template.New("")

	if len(tf) > 0 {
		tmpl = template.Must(tmpl.Parse(tf))
	} else {
		tmpl = template.Must(tmpl.Parse(tmplDHCPConf))
	}

	var buf bytes.Buffer
	candy.Must(tmpl.Execute(&buf, c))
	return buf.String()
}

// Join is defined as a method of Cluster, so can be called in
// templates.  For more details, refer to const tmplDHCPConf.
func (c Cluster) Join(s []string) string {
	return strings.Join(s, ", ")
}

// Hostname is defined as a method of Node, so can be call in
// template.  For more details, refer to const tmplDHCPConf.
func (n Node) Hostname() string {
	return strings.ToLower(strings.Replace(n.MAC, ":", "-", -1))
}

// Mac is defined as a method of Node, so can be called in template.
// For more details, refer to const tmplDHCPConf.
func (n Node) Mac() string {
	return strings.ToLower(n.MAC)
}

const (
	tmplDHCPConf = `next-server {{.Bootstrapper}};
filename "pxelinux.0";

subnet {{.Subnet}} netmask {{.Netmask}} {
    range {{.IPLow}} {{.IPHigh}};
    option broadcast-address {{.Broadcast}};
    option routers {{.Join .Routers}};
    option domain-name "{{.DomainName}}";
    option domain-name-servers {{.Join .Nameservers}};
{{range .Nodes}}{{if .IP}}
    host {{.Hostname}} {
        hardware ethernet {{.Mac}};
        fixed-address {{.IP}};
    }{{end}}{{end}}
}
`
)
