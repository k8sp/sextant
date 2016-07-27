// Package config defines Go structs that configure a Kubernetes
// cluster.  The configuration is often encoded and saved as a YAML
// file, which is used by config-bootstrapper and cloud-config-server.
package config

// Cluster configures a cluster, which includes: (1) a
// bootstrapper machine, (2) the Kubernetes cluster.
type Cluster struct {
	// Bootstrapper is the IP of the PXE server (DHCP + TFTP,
	// https://github.com/k8sp/bare-metal-coreos), which is also
	// an Ngix server and SkyDNS server
	// (https://github.com/k8sp/auto-install/tree/master/dns).
	Bootstrapper string

	// The following are for configuring the DHCP service on the
	// PXE server.  For any node, if its MAC address and IP
	// address are enlisted in Node.MAC and Node.IP, the generated
	// /etc/dhcpd/dhcp.conf will bind the IP address to the MAC
	// address; otherwise the node will be assigned an IP from
	// within the range of [IPLow, IPHigh].  In practice, nodes
	// running etcd members requires fixed IP addresses.
	Subnet        string
	Netmask       string
	Routers       []string
	Broadcast     string
	Nameservers   []string
	DomainName    string
	IPLow, IPHigh string // The IP address range of woker nodes.
	Nodes         []Node // Enlist nodes that run Kubernetes/etcd/Ceph masters.

	SSHAuthorizedKeys string `yaml:"ssh_authorized_keys"` // So maintainers can SSH to all nodes.
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
