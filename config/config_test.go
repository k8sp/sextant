package config

import (
	"html/template"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"

	"gopkg.in/yaml.v2"
)

func TestYARMLEncoding(t *testing.T) {
	c := &Cluster{}
	candy.Must(yaml.Unmarshal([]byte(testConfig), c))

	tmpl := template.Must(template.New("").Parse(tmplDHCPConf))
	assert.Nil(t, tmpl.Execute(os.Stdout, c))

	//	fmt.Println(c.InitialEtcdCluster())
}

const (
	testConfig = `
bootstrapper: 10.10.10.192

subnet: 10.10.10.0
netmask: 255.255.255.0
iplow: 10.10.10.100
iphigh: 10.10.10.199
routers: [10.10.10.192]
broadcast: 10.10.10.255
nameservers: [10.10.10.192, 8.8.8.8, 8.8.4.4]
domainname: unisound.com

nodes:
  "00:25:90:c0:f7:80":
    ip: 10.10.10.201
    ceph_monitor: y
    kube_master: y
    etcd_member: y
  "00:25:90:c0:f6:ee":
    ip: 10.10.10.202
    ceph_monitor: y
    etcd_member: y
  "00:25:90:c0:f6:d6":
    ceph_monitor: y
    etcd_member: y
  "00:25:90:c0:f7:ac":
    ip: "10.10.10.204"
  "00:25:90:c0:f7:7e":
    ip: "10.10.10.205"
`

	tmplDHCPConf = `next-server {{.Bootstrapper}};
filename "pxelinux.0";
 
subnet {{.Subnet}} netmask {{.Netmask}} {
    range {{.IPLow}} {{.IPHigh}};
    option routers {{.Join .Routers}};
    option broadcast-address {{.Broadcast}};
    option domain-name-servers {{.Join .Nameservers}}; 
    option domain-name "{{.DomainName}}";
{{range $key, $value := .Nodes}}
  {{- if $value.IP}}
    host {{.Hostname $key}} {
        hardware ethernet {{$key}};
        fixed-address {{$value.IP}};
    }
  {{- end -}}
{{end}}
}
`
)
