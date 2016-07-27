package config

import (
	"bytes"
	"html/template"

	"github.com/topicai/candy"
)

func DHCPConf(c *Cluster) string {
	tmpl := template.Must(template.New("").Parse(tmplDHCPConf))
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
{{range .Nodes}}
  {{- if .IP}}
    host {{.Hostname}} {
        hardware ethernet {{.Mac}};
        fixed-address {{.IP}};
    }
  {{- end -}}
{{end}}
}
`
)
