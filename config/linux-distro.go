package config

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"runtime"
	"strings"

	"github.com/topicai/candy"
)

// LinuxDistro returns the Linux distribution name.  Known
// distributions include "centos", "coreos", and "ubuntu".  If the
// system is not Linux or its distribution is unknown, LinuxDistro
// returns an error.
func LinuxDistro() (string, error) {
	if runtime.GOOS != "linux" {
		return "", errors.New("Not Linux")
	}

	f, e := os.Open("/etc/os-release")
	if e != nil {
		return "", e
	}
	defer candy.Must(f.Close())

	line, e := bufio.NewReader(f).ReadString('\n')
	if e != nil {
		return "", e
	}

	if strings.Contains(strings.ToLower(line), "centos") {
		return "centos", nil
	} else if strings.Contains(strings.ToLower(line), "ubuntu") {
		return "ubuntu", nil
	} else if strings.Contains(strings.ToLower(line), "coreos") {
		return "coreos", nil
	}
	return "", fmt.Errorf("Unknown OS: %v", line)
}
