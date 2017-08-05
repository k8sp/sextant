package template

import (
	"io"
	"io/ioutil"
	"strings"
	"text/template"

	"github.com/k8sp/sextant/golang/certgen"
	"github.com/k8sp/sextant/golang/clusterdesc"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

// ExecutionConfig struct config a Coreos's cloud config file which use for installing Coreos in k8s cluster.
type ExecutionConfig struct {
	Hostname                 string
	IP                       string
	CephMonitor              bool
	KubeMaster               bool
	EtcdMember               bool
	IngressLabel             bool
	FlannelIface             string
	InitialCluster           string
	SSHAuthorizedKeys        string
	EtcdEndpoints            string
	MasterIP                 string
	MasterHostname           string
	BootstrapperIP           string
	CentOSYumRepo            string
	CaCrt                    string
	Crt                      string
	Key                      string
	Dockerdomain             string
	K8sClusterDNS            string
	K8sServiceClusterIPRange string
	ZapAndStartOSD           bool
	Images                   map[string]string
	FlannelBackend           string
	RebootStrategy           string
	StartTime                string
	TimeLength               string
	CoreOSVersion            string
	GPUDriversVersion        string
	OSName                   string
	StartPXE                 bool
}

// Execute load template files from "ccTemplateDir", parse clusterDescFile to
// "clusterdesc.Cluster" struct and then run the templateName
func Execute(w io.Writer, mac, templateName, ccTemplateDir, clusterDescFile, caKey, caCrt string) error {
	// Load data from file every time, no need to read from remote url
	t, parseErr := template.ParseGlob(ccTemplateDir + "/*")
	if parseErr != nil {
		return parseErr
	}
	clusterDescBuff, readErr := ioutil.ReadFile(clusterDescFile)
	if readErr != nil {
		return readErr
	}
	c := &clusterdesc.Cluster{}
	candy.Must(yaml.Unmarshal(clusterDescBuff, c))
	confData := GetConfigDataByMac(mac, c, caKey, caCrt)
	return t.ExecuteTemplate(w, templateName, *confData)
}

// GetConfigDataByMac returns data struct for cloud-config template to execute
func GetConfigDataByMac(mac string, clusterdesc *clusterdesc.Cluster, caKey, caCrt string) *ExecutionConfig {
	node := getNodeByMAC(clusterdesc, mac)
	ca, e := ioutil.ReadFile(caCrt)
	var k, c []byte
	if e == nil {
		k, c = certgen.Gen(false, node.Hostname(), caKey, caCrt, clusterdesc.KubeMasterIP, clusterdesc.KubeMasterDNS)
		if node.KubeMaster == true {
			k, c = certgen.Gen(true, node.Hostname(), caKey, caCrt, clusterdesc.KubeMasterIP, clusterdesc.KubeMasterDNS)
		}
	}

	return &ExecutionConfig{
		Hostname:                 node.Hostname(),
		CephMonitor:              node.CephMonitor,
		KubeMaster:               node.KubeMaster,
		EtcdMember:               node.EtcdMember,
		IngressLabel:             node.IngressLabel,
		FlannelIface:             node.FlannelIface,
		InitialCluster:           clusterdesc.InitialEtcdCluster(),
		SSHAuthorizedKeys:        clusterdesc.SSHAuthorizedKeys,
		MasterHostname:           clusterdesc.GetMasterHostname(),
		EtcdEndpoints:            clusterdesc.GetEtcdEndpoints(),
		BootstrapperIP:           clusterdesc.Bootstrapper,
		CentOSYumRepo:            clusterdesc.CentOSYumRepo,
		Dockerdomain:             clusterdesc.Dockerdomain,
		K8sClusterDNS:            clusterdesc.K8sClusterDNS,
		K8sServiceClusterIPRange: clusterdesc.K8sServiceClusterIPRange,
		ZapAndStartOSD:           clusterdesc.Ceph.ZapAndStartOSD,
		Images:                   clusterdesc.Images,
		// Mulit-line context in yaml should keep the indent,
		// there is no good idea for templaet package to auto keep the indent so far,
		// so insert 6*whitespace at the begging of every line
		CaCrt:             strings.Join(strings.Split(string(ca), "\n"), "\n      "),
		Crt:               strings.Join(strings.Split(string(c), "\n"), "\n      "),
		Key:               strings.Join(strings.Split(string(k), "\n"), "\n      "),
		FlannelBackend:    clusterdesc.FlannelBackend,
		RebootStrategy:    clusterdesc.CoreOS.RebootStrategy,
		StartTime:         clusterdesc.CoreOS.StartTime,
		TimeLength:        clusterdesc.CoreOS.TimeLength,
		CoreOSVersion:     clusterdesc.CoreOSVersion,
		GPUDriversVersion: clusterdesc.GPUDriversVersion,
		OSName:            clusterdesc.OSName,
		StartPXE:          clusterdesc.StartPXE,
	}
}

func getNodeByMAC(c *clusterdesc.Cluster, mac string) clusterdesc.Node {
	for _, n := range c.Nodes {
		if n.Mac() == mac {
			return n
		}
	}
	return clusterdesc.Node{MAC: mac, CephMonitor: false, KubeMaster: false, EtcdMember: false}
}
