package config

import (
	"fmt"
	"strings"
)

// InitialEtcdCluster derives the value of command line parameter
// --initial_cluster of etcd from Cluter.Nodes and Node.EtcdMember.
// NOTE: Every node in the cluster will have a etcd daemon running --
// either as a member or as a proxy.
func (c Cluster) InitialEtcdCluster() string {
	var ret []string
	for _, n := range c.Nodes {
		if n.EtcdMember {
			name := n.Hostname()
			addr := n.Hostname()
			if len(n.IP) > 0 {
				addr = n.IP // No need for DNS then.
			}
			ret = append(ret, fmt.Sprintf("%s=http://%s:2380", name, addr))
		}
	}
	return strings.Join(ret, ",")
}

// Get Etcd machines list
func (c Cluster) GetEtcdMachines() string {
	var ret []string
	for _, n := range c.Nodes {
		if n.EtcdMember {
			if len(n.IP) > 0 {
				ret = append(ret, fmt.Sprintf("http://%s:2379", n.IP))
			}
		}
	}
	return strings.Join(ret, ",")
}
