package vmtest

import "flag"

var (
	InVM = flag.Bool("test.invm", false, "The test is running in a VM.")
)
