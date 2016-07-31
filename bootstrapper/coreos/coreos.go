package coreos

import (
	"fmt"
	"log"
	"strings"

	"github.com/wangkuiyi/sh"
)

// GetVersion returns the most recent version of the specified CoreOS
// channel. channel could be "stable", "beta", or "alpha".
func GetVersion(channel string) string {
	url := fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/current/version.txt", channel)
	ver := <-sh.Grep(sh.Run("curl", url), "COREOS_VERSION=")
	fs := strings.Split(ver, "=")
	if len(fs) != 2 {
		log.Panicf("Unknown version line from %s: %s", url, ver)
	}
	return fs[1]
}
