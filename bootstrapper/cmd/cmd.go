package cmd

import (
	"flag"
	"log"
	"os"
	"os/exec"
	"strings"
)

var (
	Silent = flag.Bool("cmd.silent", false, "If cmd.Run displays outputs of commands")
)

// Run runs a command that doesn't need any input from the stdin.  It
// log.Panic the stdout and stderr of the command, only if the
// execution goes wrong.
func Run(name string, arg ...string) {
	run(true, name, arg)
}

func Try(name string, arg ...string) {
	run(false, name, arg)
}

func run(panic bool, name string, arg []string) {
	log.Printf("Running %s %s ...", name, strings.Join(arg, " "))
	cmd := exec.Command(name, arg...)

	p := log.Printf
	if panic {
		p = log.Panicf
	}

	if *Silent {
		b, e := cmd.CombinedOutput()
		if e != nil {
			p("Command \"%s %s\" error: %v\nwith output:\n%s", name, strings.Join(arg, " "), e, string(b))
		}
	} else {
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if e := cmd.Run(); e != nil {
			p("Command \"%s %s\" error: %v", name, strings.Join(arg, " "), e)
		}
	}
}
