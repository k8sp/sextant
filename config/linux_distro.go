package config

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"runtime"
	"strings"
)

func LinuxDistro() (string, error) {
	if runtime.GOOS != "linux" {
		return "", errors.New("Not Linux")
	}

	f, e := os.Open("/etc/os-release")
	if e != nil {
		return "", e
	}
	defer f.Close()

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
	} else {
		return "", fmt.Errorf("Unknown OS: %v", line)
	}
}
