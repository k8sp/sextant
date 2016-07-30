package cmd

import (
	"flag"
	"log"
	"os"
	"os/exec"

	"github.com/topicai/candy"
)

var (
	Silent = flag.Bool("cmd.silent", false, "If cmd.Run displays outputs of commands")
)

// Run runs a command that doesn't need any input from the stdin.  It
// log.Panic the stdout and stderr of the command, only if the
// execution goes wrong.
func Run(name string, arg ...string) {
	cmd := exec.Command(name, arg...)

	if *Silent {
		b, e := cmd.CombinedOutput()
		if e != nil {
			log.Panic(e, string(b))
		}
	} else {
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		candy.Must(cmd.Run())
	}
}
