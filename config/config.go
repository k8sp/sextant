// Package config defines Go structs that configure a Kubernetes
// cluster.  The configuration is often encoded and saved as a YAML
// file, which is used by config-bootstrapper and cloud-config-server.
package config

import "strings"

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

	NginxRootDir string `yaml:"nginx_root_dir"`

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

// Join is defined as a method of Cluster, so can be called in
// templates.  For more details, refer to const tmplDHCPConf.
func (c Cluster) Join(s []string) string {
	return strings.Join(s, ", ")
}

// Hostname is defined as a method of Node, so can be call in
// template.  For more details, refer to const tmplDHCPConf.
func (n Node) Hostname() string {
	return strings.ToLower(strings.Replace(n.MAC, ":", "-", -1))
}

// Mac is defined as a method of Node, so can be called in template.
// For more details, refer to const tmplDHCPConf.
func (n Node) Mac() string {
	return strings.ToLower(n.MAC)
}

// ExampleYAML shows an example of YAML-encoded Cluster description.
// It is also used for unit testing.
const ExampleYAML = `
bootstrapper: 10.10.10.192

subnet: 10.10.10.0
netmask: 255.255.255.0
iplow: 10.10.10.100
iphigh: 10.10.10.199
routers: [10.10.10.192]
broadcast: 10.10.10.255
nameservers: [10.10.10.192, 8.8.8.8, 8.8.4.4]
domainname: unisound.com

nginx_root_dir: /usr/share/nginx/html

nodes:
  - mac: "00:25:90:c0:f7:80"
    ip: 10.10.10.201
    ceph_monitor: y
    kube_master: y
    etcd_member: y
  - mac: "00:25:90:c0:f6:ee"
    ip: 10.10.10.202
    ceph_monitor: y
    etcd_member: y
  - mac: "00:25:90:c0:f6:d6"
    ceph_monitor: y
    etcd_member: y
  - mac: "00:25:90:c0:f7:ac"
    ip: "10.10.10.204"
  - mac: "00:25:90:c0:f7:7e"
    ip: "10.10.10.205"
`
