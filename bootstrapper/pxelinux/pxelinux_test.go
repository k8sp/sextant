package pxelinux

import (
	"flag"
	"os"
	"testing"

	"gopkg.in/yaml.v2"

	"log"

	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
)

var (
	indocker = flag.Bool("indocker", false,
		"Tells that the test is running in a Docker container.")
)

func TestInstall(t *testing.T) {
	if *indocker {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		Install()

		switch config.LinuxDistro() {
		case "ubuntu":
			{
				if _, err := os.Stat("/usr/lib/PXELINUX/pxelinux.0"); os.IsNotExist(err) {
					log.Printf("Failed to install/configure pxelinux, /usr/lib/PXELINUX/pxelinux.0 doesn't exist")
				}
				if _, err := os.Stat("/usr/lib/syslinux/modules/bios/ldlinux.c32"); os.IsNotExist(err) {
					log.Printf("Failed to install/configure pxelinux, /usr/lib/syslinux/modules/bios/ldlinux.c32 doesn't exist")
				}
			}
		case "centos":
			if _, err := os.Stat("/usr/share/syslinux/pxelinux.0"); os.IsNotExist(err) {
				log.Printf("Failed to install/configure pxelinux, /usr/share/syslinux/pxelinux.0 doesn't exist")
			}

		}

	}
}
