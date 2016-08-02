package vmtest

import "flag"

var (
	InVM = flag.Bool("invm", false, "The test is running in a VM.")
)
