// Package clusterdesc defines Go structs that configure a Kubernetes
// cluster.  The configuration is often encoded and saved as a YAML
// file, which is used by config-bootstrapper and cloud-config-server.
package clusterdesc

import (
	"net"
	"strings"

	"github.com/topicai/candy"
)

// Cluster configures a cluster, which includes: (1) a
// bootstrapper machine, (2) the Kubernetes cluster.
type Cluster struct {
	// Bootstrapper is the IP of the PXE server (DHCP + TFTP,
	// https://github.com/k8sp/bare-metal-coreos), which is also
	// an Ngix server and SkyDNS server
	// (https://github.com/k8sp/sextant/tree/master/dns).
	Bootstrapper string

	// The following are for configuring the DHCP service on the
	// PXE server.  For any node, if its MAC address and IP
	// address are enlisted in Node.MAC and Node.IP, the generated
	// /etc/dnsmasq/dnsmasq.conf will bind the IP address to the MAC
	// address; otherwise the node will be assigned an IP from
	// within the range of [IPLow, IPHigh].  In practice, nodes
	// running etcd members requires fixed IP addresses.
	Subnet              string
	Netmask             string
	Routers             []string
	Broadcast           string
	Nameservers         []string
	UpstreamNameServers []string
	DomainName          string `yaml:"domainname"`
	IPLow, IPHigh       string // The IP address range of woker nodes.
	Nodes               []Node // Enlist nodes that run Kubernetes/etcd/Ceph masters.

	CoreOSChannel string `yaml:"coreos_channel"`

	NginxRootDir string `yaml:"nginx_root_dir"`

	SSHAuthorizedKeys        string `yaml:"ssh_authorized_keys"` // So maintainers can SSH to all nodes.
	Dockerdomain             string
	K8sClusterDNS            string `yaml:"k8s_cluster_dns"`
	K8sServiceClusterIPRange string `yaml:"k8s_service_cluster_ip_range"`
	Ceph                     Ceph
	Images                   map[string]string
	FlannelBackend           string `yaml:"flannel_backend"`
	IngressHostNetwork       bool   `yaml:"ingress_hostnetwork"`
	CoreOS                   CoreOS
	CoreOSVersion            string   `yaml:"coreos_version"`
	GPUDriversVersion        string   `yaml:"gpu_drivers_version"`
	OSName                   string   `yaml:"os_name"`
	KubeMasterIP             []string `yaml:"kube_master_ip"`
	KubeMasterDNS            []string `yaml:"kube_master_dns"`
	DNSMASQSetNTP            bool     `yaml:"set_ntp"`
	DNSMASQLease             string   `yaml:"lease"`
	CentOSYumRepo            string   `yaml:"set_yum_repo"`
	StartPXE                 bool     `yaml:"start_pxe"`
}

// CoreOS defines the system related operations, such as: system updates.
type CoreOS struct {
	RebootStrategy string `yaml:"reboot_strategy"`
	StartTime      string `yaml:"start_time"`
	TimeLength     string `yaml:"time_length"`
}

// Ceph consists configs for ceph deploy
type Ceph struct {
	ZapAndStartOSD bool `yaml:"zap_and_start_osd"`
	OSDJournalSize int  `yaml:"osd_journal_size"`
}

// Node defines properties of some nodes in the cluster.  For example,
// for those nodes on which we install etcd members, we prefer that
// the DHCP server assigns them fixed IPs.  This can be done by
// specify Node.IP.  Also, some of nodes can also have Kubernetes
// master or Ceph monitor installed as well.  NOTE: for nodes with IP
// specified in Node.IP, these IPs should not be in the range of
// Cluster.IPLow and Cluster.IPHigh.
type Node struct {
	MAC          string
	CurHostName  string `yaml:"cur_host_name"`
	IngressLabel bool
	CephMonitor  bool   `yaml:"ceph_monitor"`
	KubeMaster   bool   `yaml:"kube_master"`
	EtcdMember   bool   `yaml:"etcd_member"`
	FlannelIface string `yaml:"flannel_iface"`
}

// Join is defined as a method of Cluster, so can be called in
// templates.  For more details, refer to const tmplDHCPConf.
func (c Cluster) Join(s []string) string {
	return strings.Join(s, ", ")
}

// GetIngressReplicas return replica number of the ingress node
func (c Cluster) GetIngressReplicas() int {
	var cnt = 0
	for _, n := range c.Nodes {
		if n.IngressLabel {
			cnt++
		}
	}
	return cnt
}

// Hostname is defined as a method of Node, so can be call in
// template.  For more details, refer to const tmplDHCPConf.
func (n Node) Hostname() string {
	if n.CurHostName != "" {
		return n.CurHostName
	}
	return strings.ToLower(strings.Replace(n.Mac(), ":", "-", -1))
}

// Mac is defined as a method of Node, so can be called in template.
// For more details, refer to const tmplDHCPConf.
func (n Node) Mac() string {
	hwAddr, err := net.ParseMAC(n.MAC)
	candy.Must(err)
	return hwAddr.String()
}
