package coreos

import (
	"flag"
	"log"
	"strings"
	"testing"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
	"github.com/stretchr/testify/assert"
)

var (
	indocker = flag.Bool("indocker", false, "Tells that the test is running in a Docker container.")
)

func TestGetVersion(t *testing.T) {
	alpha := GetVersion("alpha")
	beta := GetVersion("beta")
	stable := GetVersion("stable")
	assert.True(t, strings.Compare(stable, beta) <= 0)
	assert.True(t, strings.Compare(beta, alpha) <= 0)
}

func TestDownloadBootImage(t *testing.T) {
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

		DownloadBootImage("stable", "/tmp")
	}
}
