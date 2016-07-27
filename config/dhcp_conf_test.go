package config

import (
	"bytes"
	"html/template"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"

	"gopkg.in/yaml.v2"
)

func TestYARMLEncoding(t *testing.T) {
	c := &Cluster{}
	candy.Must(yaml.Unmarshal([]byte(testConfig), c))

	tmpl := template.Must(template.New("").Parse(tmplDHCPConf))

	var buf bytes.Buffer
	assert.Nil(t, tmpl.Execute(&buf, c))

	assert.Equal(t, buf.String(), dhcpConf)
}

const (
	dhcpConf = `next-server 10.10.10.192;
filename "pxelinux.0";

subnet 10.10.10.0 netmask 255.255.255.0 {
    range 10.10.10.100 10.10.10.199;
    option broadcast-address 10.10.10.255;
    option routers 10.10.10.192;
    option domain-name "unisound.com";
    option domain-name-servers 10.10.10.192, 8.8.8.8, 8.8.4.4;

    host 00-25-90-C0-F7-80 {
        hardware ethernet 00:25:90:C0:F7:80;
        fixed-address 10.10.10.201;
    }
    host 00-25-90-C0-F6-EE {
        hardware ethernet 00:25:90:C0:F6:EE;
        fixed-address 10.10.10.202;
    }
    host 00-25-90-C0-F7-AC {
        hardware ethernet 00:25:90:C0:F7:AC;
        fixed-address 10.10.10.204;
    }
    host 00-25-90-C0-F7-7E {
        hardware ethernet 00:25:90:C0:F7:7E;
        fixed-address 10.10.10.205;
    }
}
`
)
