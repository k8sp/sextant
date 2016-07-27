package config

type Filter h func(arg interface{}) chan interface{}

func du(arg interface{}) chan interface{} {
	recurs := func(arg string, out chan interface{}) {
		fis, e := ioutil.ReadDir(arg)
		if e != nil {
			panic(e)
		}

		for _, fi := range fis {
			fullname = path.Join(dirname, fi.Name())
			if fi.IsDir() {
				recurs(fullname, out)
			} else {
				out <- fullname
			}
		}
	}

	out := make(chan inteface{})
	go recurs(arg.(string), out)
	return out
}

func greper(pattern string) Filter {
	return func(arg interface{}) chan interface{} {
		filename := arg.(string)
		out := make(chan interface{})

		go candy.WithOpened(filename, func(r io.Reader) interface{} {
			s := bufio.NewScanner(bufio.NewReader(r))
			for s.Scan() {
				line := s.Text()
				if strings.Contains(line, pattern) {
					out <- line
				}
			}
			if e := s.Err(); e != nil {
				panic(e)
			}
			close(out)
		})
		return out
	}
}



func foreach(in chan interface{}, h Filter) chan interface{} {
	out := make(chan interface{})
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

func CheckStaticIP(nic stirng) error {
	r := <- foreach(du("/etc/network/interfaces.d"), greper("iface "+nic))
	fmt.Println(r)
}
