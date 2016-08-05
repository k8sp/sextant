package dhcp

import (
	"testing"

	"github.com/k8sp/auto-install/config"
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func TestConf(t *testing.T) {
	c := &config.Cluster{}
	candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))
	assert.Equal(t, dhcpConf, Conf("", c))
}

const (
	dhcpConf = `next-server 10.0.2.15;
filename "pxelinux.0";

subnet 10.0.2.0 netmask 255.255.255.0 {
    range 10.0.2.100 10.0.2.200;
    option broadcast-address 10.0.2.255;
    option routers 10.0.2.15;
    option domain-name "company.com";
    option domain-name-servers 10.0.2.15, 8.8.8.8, 8.8.4.4;

    host 00-25-90-c0-f7-80 {
        hardware ethernet 00:25:90:c0:f7:80;
        fixed-address 10.0.2.21;
    }
    host 00-25-90-c0-f6-ee {
        hardware ethernet 00:25:90:c0:f6:ee;
        fixed-address 10.0.2.22;
    }
    host 00-25-90-c0-f7-ac {
        hardware ethernet 00:25:90:c0:f7:ac;
        fixed-address 10.0.2.23;
    }
}
`
)
