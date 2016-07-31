package skydns

import (
	"flag"
	"log"
	"testing"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
)

var (
	indocker = flag.Bool("indocker", false,
		"Tells that the test is running in a Docker container.")
)

func TestSkyDNS(t *testing.T) {
	if *indocker {
		const (
			centos = "centos"
			ubuntu = "ubuntu"
		)

		switch dist := config.LinuxDistro(); dist {
		case centos:
			cmd.Run("yum", "-y", "install", "curl")
		case ubuntu:
			cmd.Run("apt-get", "update")
			cmd.Run("apt-get", "-y", "install", "curl")
		default:
			log.Panicf("Unsupported OS: %s", dist)
		}

		DownloadSkyDNSBinary("/usr/bin")
	}
}
