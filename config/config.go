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

	Subnet        string          // e.g., 192.168.2.0
	Netmask       string          // e.g., 255.255.255.0
	IPLow, IPHigh string          // e.g., 192.168.2.11, 192.168.2.249
	Routers       []string        // e.g., [192.168.2.1]
	Broadcast     string          // e.g., 192.168.2.255
	Nameservers   []string        // e.g., [8.8.8.8, 8.8.4.4]
	DomainName    string          // e.g., unisound.com
	Nodes         map[string]Node // node roles and fixed IPs.

	SSHAuthorizedKeys string `yaml:"ssh_authorized_keys"`
	SSHPrivateKey     string `yaml:"ssh_private_key"`
}

type Node struct {
	IP          string `yaml:"ip"` // if empty, no fixed IP.
	CephMonitor bool   `yaml:"ceph_monitor"`
	KubeMaster  bool   `yaml:"kube_master"`
	EtcdMember  bool   `yaml:"etcd_member"`
}

func (c Cluster) Join(s []string) string {
	return strings.Join(s, ", ")
}

func (n Node) Hostname(mac string) string {
	return strings.Replace(mac, ":", "-", -1)
}

func (c Cluster) InitialEtcdCluster() string {
	ret := make([]string, 0)
	for k, v := range c.Nodes {
		if v.EtcdMember {
			name := v.Hostname(k)
			addr := v.Hostname(k)
			if len(v.IP) > 0 {
				addr = v.IP // No need for DNS then.
			}
			ret = append(ret, fmt.Sprintf("%s=http://%s:2380", name, addr))
		}
	}
	return strings.Join(ret, ",")
}
