package config

import (
	"bufio"
	"fmt"
	"io"
	"io/ioutil"
	"path"
	"regexp"
	"strings"

	"github.com/topicai/candy"
)

// Filter is a common form of many of the following functions, that
// take one string-typed argument and return a channel of strings.
// Implementations of Filter should create the channel, run a
// goroutine to fill and then close the channel, and returns the
// channel immediately.  Therefore we can chain up filters like Bash
// pipelines using glue operations like ForEach.
type Filter func(arg string) chan string

// Echo splits arg by "\n" and outputs each line.
func Echo(arg string) chan string {
	out := make(chan string)
	go func() {
		for _, seg := range strings.Split(arg, "\n") {
			out <- seg
		}
		close(out)
	}()
	return out
}

// ToFile reads lines from in and writes them into a file.
func ToFile(in chan string, filename string) {
	candy.WithCreated(filename, func(w io.Writer) {
		for l := range in {
			fmt.Fprintf(w, "%s\n", l)
		}
	})
}

// Cat reads from file named arg line-by-line.
func Cat(arg string) chan string {
	out := make(chan string)

	go candy.WithOpened(arg, func(r io.Reader) interface{} {
		s := bufio.NewScanner(bufio.NewReader(r))
		for s.Scan() {
			out <- s.Text()
		}
		if e := s.Err(); e != nil {
			panic(e)
		}
		close(out)
		return nil
	})

	return out
}

// Head reads the first line from in and writes it, while consuming
// and ignoring all rest lines.
func Head(in chan string, n int) chan string {
	out := make(chan string)
	go func() {
		for l := range in {
			if n > 0 {
				out <- l
				n--
			}
		}
		close(out)
	}()
	return out
}

// Wc consumes in and counts the number of lines in it.
func Wc(in chan string) int {
	n := 0
	for range in {
		n++
	}
	return n
}

func recursDu(dirname string, out chan string) {
	fis, e := ioutil.ReadDir(dirname)
	if e != nil {
		panic(e)
	}

	for _, fi := range fis {
		fullname := path.Join(dirname, fi.Name())
		if fi.IsDir() {
			recursDu(fullname, out)
		} else {
			out <- fullname
		}
	}
}

// Du takes a directory name and recursively lists all files (not
// sub-directories) in that directory.
func Du(dirname string) chan string {
	out := make(chan string)
	go func() {
		recursDu(dirname, out)
		close(out)
	}()
	return out
}

// Grep consumes all lines from in, and writes those contains pattern.
func Grep(in chan string, pattern string) chan string {
	out := make(chan string)
	go func() {
		r := regexp.MustCompile(pattern)
		for l := range in {
			if r.Find([]byte(l)) != nil {
				out <- l
			}
		}
		close(out)
	}()
	return out
}

// ForEach runs h for each line from in.  It copies outputs from all h
// invocations to its own output channel.
func ForEach(in chan string, h Filter) chan string {
	out := make(chan string)
	go func() {
		for x := range in {
			for hout := range h(x) {
				out <- hout
			}
		}
		close(out)
	}()
	return out
}
