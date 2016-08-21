package config

import (
	"fmt"
	"strings"
)

// GetMasterIP  fetch master node ip
func (c Cluster) GetMasterIP() string {
	var ret []string
	for _, n := range c.Nodes {
		if n.KubeMaster {
			addr := n.Hostname()
			if len(n.IP) > 0 {
				addr = n.IP // No need for DNS then.
			}
			ret = append(ret, fmt.Sprintf("%s", addr))
		}
	}
	return strings.Join(ret, ",")
}

// GetMasterHostname fetch master node hostname
func (c Cluster) GetMasterHostname() string {
	var ret []string
	for _, n := range c.Nodes {
		if n.KubeMaster {
			addr := n.Hostname()
			ret = append(ret, fmt.Sprintf("%s", addr))
		}
	}
	return strings.Join(ret, ",")
}
