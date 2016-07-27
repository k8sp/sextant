// Package config defines Go structs that configure a Kubernetes
// cluster.  The configuration is often encoded and saved as a YAML
// file, which is used by config-bootstrapper and cloud-config-server.
package config

import (
	"fmt"
	"strings"
)

// Cluster configures a cluster, which includes: (1) a
// bootstrapper machine, (2) the Kubernetes cluster.
type Cluster struct {
	Bootstrapper string // e.g., 192.168.2.10

	Subnet        string   // e.g., 192.168.2.0
	Netmask       string   // e.g., 255.255.255.0
	IPLow, IPHigh string   // e.g., 192.168.2.11, 192.168.2.249
	Routers       []string // e.g., [192.168.2.1]
	Broadcast     string   // e.g., 192.168.2.255
	Nameservers   []string // e.g., [8.8.8.8, 8.8.4.4]
	DomainName    string   // e.g., unisound.com
	Nodes         []Node   // node roles and fixed IPs.

	SSHAuthorizedKeys string `yaml:"ssh_authorized_keys"`
	SSHPrivateKey     string `yaml:"ssh_private_key"`
}

// Node defines properties of some nodes in the cluster.  For example,
// for those nodes on which we install etcd members, we prefer that
// the DHCP server assigns them fixed IPs.  This can be done by
// specify Node.IP.  Also, some of nodes can also have Kubernetes
// master or Ceph monitor installed as well.  NOTE: for nodes with IP
// specified in Node.IP, these IPs should not be in the range of
// Cluster.IPLow and Cluster.IPHigh.
type Node struct {
	MAC         string
	IP          string // if empty, no fixed IP.
	CephMonitor bool   `yaml:"ceph_monitor"`
	KubeMaster  bool   `yaml:"kube_master"`
	EtcdMember  bool   `yaml:"etcd_member"`
}

// Join is defined as a method of Cluster, so can be called in
// templates.
func (c Cluster) Join(s []string) string {
	return strings.Join(s, ", ")
}

// Hostname is defined as a method of Node, so can be call in
// template.
func (n Node) Hostname() string {
	return strings.ToUpper(strings.Replace(n.MAC, ":", "-", -1))
}

// Mac is defined as a method of Node, so can be called in template.
func (n Node) Mac() string {
	return strings.ToUpper(n.MAC)
}

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
