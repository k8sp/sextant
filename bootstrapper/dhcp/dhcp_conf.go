package dhcp

import (
	"bytes"
	"html/template"

	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
)

// Conf executes a template with a Cluster variable to generate
// /etc/dhcpd/dhcp.conf.
func Conf(tf string, c *config.Cluster) string {
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
