// Package config defines Go structs that configure a Kubernetes
// cluster.  The configuration is often encoded and saved as a YAML
// file, which is used by config-bootstrapper and cloud-config-server.
package config

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
