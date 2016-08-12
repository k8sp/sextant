package main

import (
	"flag"
	"fmt"
	"time"

	"github.com/k8sp/auto-install/bootstrapper/initcoreos"
	"github.com/k8sp/auto-install/cache"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
	yaml "gopkg.in/yaml.v2"
)

// Bootstrapper config use command line flags or yaml config files
type Bootstrapper struct {
	downloadCoreOS *bool
	clusterDescURL *string
}

// NewBootstrapper init bootstrapper main configs
func NewBootstrapper() *Bootstrapper {
	return &Bootstrapper{
		downloadCoreOS: nil,
		clusterDescURL: nil,
	}
}

var bsConf = NewBootstrapper()

func init() {
	bsConf.downloadCoreOS = flag.Bool("download-coreos", false,
		"download and update CoreOS images in the background")
	bsConf.clusterDescURL = flag.String("cluster-desc-url",
		"https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/unisound-ailab/build_config.yml",
		"cluster desc file config url")
	flag.Parse()
}

func main() {
	// init cluster desc file cache
	confCache := cache.MakeCacheGetter(*bsConf.clusterDescURL, "clusterDesc.txt")
	c := &config.Cluster{}
	candy.Must(yaml.Unmarshal(confCache(), c))

	// start download coreos routine if needed
	if *bsConf.downloadCoreOS == true {
		ticker := time.NewTicker(time.Minute * 30)
		defer ticker.Stop()
		go func() {
			for t := range ticker.C {
				fmt.Println("Tick at", t)
				initcoreos.CheckAndDownload(c)
			}
		}()
	}
	// FIXME: add bootstrapper (concurrent) steps below:
	// 1. start dnsmasq container(privilleged)
	// 2. start cloud-config-server
	// 3. start a docker registry and push k8s images into it

	// run for ever
	for {
		time.Sleep(time.Second * 1)
	}
}
