package cmd

import (
	"flag"
	"fmt"
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
	run(true, nil, name, arg)
}

// Try works like Run, but doesn't panic if the commands returns a
// non-zero value.
func Try(name string, arg ...string) {
	run(false, nil, name, arg)
}

// RunWithEnv works like Run, but allows the user to set the environment
// variables, in addition to those inherited from the parent process.
func RunWithEnv(env map[string]string, name string, arg ...string) {
	run(true, env, name, arg)
}

// TryWithEnv works like Try, but allows the user to set the environment
// variables, in addition to those inherited from the parent process.
func TryWithEnv(env map[string]string, name string, arg ...string) {
	run(false, env, name, arg)
}

func run(panic bool, env map[string]string, name string, arg []string) {
	log.Printf("Running %s %s ...", name, strings.Join(arg, " "))
	cmd := exec.Command(name, arg...)

	// Inherit environ from the parent process. Note that, instead
	// of appending env to cmd.Env, we rewrite the value of an
	// environment varaible in cmd.Env if it is in env.  This
	// prevents from cases like two GOPATH variables in cmd.Env.
	for _, en := range os.Environ() {
		kv := strings.Split(en, "=")
		if v := env[kv[0]]; v != "" {
			en = fmt.Sprintf("%s=%s", kv[0], v)
			delete(env, kv[0])
		}
		cmd.Env = append(cmd.Env, en)
	}

	for k, v := range env {
		cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", k, v))
	}
	if env != nil {
		log.Printf("ENV: %s", strings.Join(cmd.Env, " "))
	}

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
