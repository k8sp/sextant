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

## Prerequisite

`vmtest/run` requires
[Vagrant scp plugin](https://github.com/invernizzi/vagrant-scp).  To
install it, type

```
vagrant plugin install vagrant-scp
```

## Usage

An example is in `bootstrapper/dhcp`.  To run the tests in a Ubuntu VM
and then in a CentOS VM:

```
cd bootstrapper/dhcp
../vmtest/run
```

## Troubleshooting

### Out-Of-Memory

Some unit tests might need more memory than created by `vagrant init`;
or they will cause out-of-memory error.  For that case

### Anti-GFW

In order to use an HTTP proxy, we can change the following the line in
`vmtest/sh`

```
vagrant ssh -c "sudo /home/vagrant/$PKG.test -test.invm"
```

into

```
vagrant ssh -c "sudo http_proxy=xxxx https_proxy=yyyy /home/vagrant/$PKG.test -test.invm"
```
