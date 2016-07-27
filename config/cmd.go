package config

import (
	"log"
	"os/exec"
)

// Cmd runs a command that doesn't need any input from the stdin.  It
// log.Panic the stdout and stderr of the command, only if the
// execution goes wrong.
func Cmd(name string, arg ...string) {
	cmd := exec.Command(name, arg...)
	b, e := cmd.CombinedOutput()
	if e != nil {
		log.Panic(e, string(b))
	}
}
