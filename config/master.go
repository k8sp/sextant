package config

import (
	"fmt"
	"strings"
)

// InitialEtcdCluster derives the value of command line parameter
// --initial_cluster of etcd from Cluter.Nodes and Node.EtcdMember.
// NOTE: Every node in the cluster will have a etcd daemon running --
// either as a member or as a proxy.
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

// GetMasterHostname
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
