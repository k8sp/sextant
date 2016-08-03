# VMTest

## Motivations

Some unit tests are dependent with Linux distributions.  To run them,
we can use `./run` to build them for Linux/AMD64 and run them in VMs
with corresponding Linux distributions installed.

`./run` runs built unit test binaries with command line parameter
`--invm`, which corresponds to the global variable `vmtest.InVM`.  So
we can write our Linux-distribution-dependent unit tests in the form
of:

```
func TestSomething(t *testing.T) {
    if *vmtest.InVM {
        ....
    }
}
```

## Usage

An example is in `bootstrapper/dhcp`.  To run the tests in a Ubuntu VM
and then in a CentOS VM:

```
cd bootstrapper/dhcp
../vmtest/run
```

