# bootstrapper
Setup one machine to bootstrap an entire kubernetes cluster

# Design
Bootstrapper runs on a single machine in the cluster, docker environment is needed to setup bootstrapper.

1. Entry: read user configuration from command line or yaml file, then setup components below according to user configurations, see [bootstrapper.go](./bootstrapper.go).
1.CoreOS image updater: Download the current version of coreos images to PXE specified directory, at bootstrapping stage(release channel is also configurable), then try to update the image, so newly installed workers will be using the latest version of CoreOS, and of course, machines installed previously will update automatically by themselves.
1. dnsmasq: install and setup dnsmasq in docker according to https://github.com/k8sp/auto-install/issues/102
1. docker registry: setup a docker registry on the bootstrapper machine, and serve all the docker images that kubernetes master/worker will use, so that master/worker installation will no longer need internet access.

* Notice: all the steps can run concurrently, so each step will be a go routine. Entry manages these go routines.
