package clusterdesc

import (
	"fmt"
	"strings"
)

// SelectNodes input node role condition,
// ouptut hostname range
func (c *Cluster) SelectNodes(f func(n *Node) string) string {
	var ret []string
	for i := range c.Nodes {
		t := f(&(c.Nodes[i]))
		if len(t) > 0 {
			ret = append(ret, t)
		}
	}
	return strings.Join(ret, ",")
}

// InitialEtcdCluster derives the value of command line parameter
// --initial_cluster of etcd from Cluter.Nodes and Node.EtcdMember.
// NOTE: Every node in the cluster will have a etcd daemon running --
// either as a member or as a proxy.
func (c *Cluster) InitialEtcdCluster() string {
	return c.SelectNodes(func(n *Node) string {
		if n.EtcdMember {
			name := n.Hostname()
			addr := n.Hostname()
			return fmt.Sprintf("%s=http://%s:2380", name, addr)
		}
		return ""
	})
}

// GetEtcdEndpoints fetch etcd cluster endpoints
func (c *Cluster) GetEtcdEndpoints() string {
	return c.SelectNodes(func(n *Node) string {
		if n.EtcdMember {
			addr := n.Hostname()
			return fmt.Sprintf("http://%s:4001", addr)
		}
		return ""
	})
}

// GetEtcdMachines return the etcd members
func (c *Cluster) GetEtcdMachines() string {
	return c.SelectNodes(func(n *Node) string {
		if n.EtcdMember {
			if len(n.Hostname()) > 0 {
				return fmt.Sprintf("http://%s:2379", n.Hostname())
			}
		}
		return ""
	})
}
