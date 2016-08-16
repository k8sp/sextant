package main

import (
	"flag"
	"fmt"
	"time"

	"github.com/k8sp/auto-install/bootstrapper_in_docker/initcoreos"
	"github.com/k8sp/auto-install/cache"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
	yaml "gopkg.in/yaml.v2"
)

func main() {
	// init clusterdesc file cache
	clusterDescURL := flag.String("cluster-desc-url",
		"https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/unisound-ailab/build_config.yml",
		"URL to remote cluster description YAML file.")
	clusterDescFile := flag.String("cluster-desc-file", "./cluster-desc.yml", "Local copy of cluster description YAML file.")
	flag.Parse()

	confCache := cache.MakeCacheGetter(*clusterDescURL, *clusterDescFile)
	c := &config.Cluster{}
	candy.Must(yaml.Unmarshal(confCache(), c))

	// start download coreos routine if needed
	if c.DownloadCoreOS == true {
		ticker := time.NewTicker(time.Second * 5)
		defer ticker.Stop()
		go func() {
			for t := range ticker.C {
				fmt.Println("Download CoreOS image... Tick at", t)
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
