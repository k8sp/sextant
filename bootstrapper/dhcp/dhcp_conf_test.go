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
	dhcpConf = `next-server 10.10.10.192;
filename "pxelinux.0";

subnet 10.10.10.0 netmask 255.255.255.0 {
    range 10.10.10.100 10.10.10.199;
    option broadcast-address 10.10.10.255;
    option routers 10.10.10.192;
    option domain-name "unisound.com";
    option domain-name-servers 10.10.10.192, 8.8.8.8, 8.8.4.4;

    host 00-25-90-c0-f7-80 {
        hardware ethernet 00:25:90:c0:f7:80;
        fixed-address 10.10.10.201;
    }
    host 00-25-90-c0-f6-ee {
        hardware ethernet 00:25:90:c0:f6:ee;
        fixed-address 10.10.10.202;
    }
    host 00-25-90-c0-f7-ac {
        hardware ethernet 00:25:90:c0:f7:ac;
        fixed-address 10.10.10.204;
    }
    host 00-25-90-c0-f7-7e {
        hardware ethernet 00:25:90:c0:f7:7e;
        fixed-address 10.10.10.205;
    }
}
`
)
