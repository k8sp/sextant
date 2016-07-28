package config

import (
	"log"
	"runtime"
	"strings"

	"github.com/wangkuiyi/sh"
)

// LinuxDistro returns known distribution names, including centos,
// coreos, and ubuntu, if the current system is Linux, or panics
// otherwise.
func LinuxDistro() string {
	if runtime.GOOS != "linux" {
		log.Panicf("Not Linux, but %s", runtime.GOOS)
	}

	line := strings.ToLower(<-sh.Head(sh.Cat("/etc/os-release"), 1))

	if strings.Contains(line, "CentOS") {
		return "centos"
	} else if strings.Contains(line, "Ubuntu") {
		return "ubuntu"
	} else if strings.Contains(line, "CoreOS") {
		return "coreos"
	}
	log.Panicf("Unknown OS %s", line)
	return "" // dummpy return
}
