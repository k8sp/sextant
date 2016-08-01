# auto-install

[![Build Status](https://travis-ci.org/k8sp/auto-install.png?branch=master)](https://travis-ci.org/k8sp/auto-install) [![GoDoc](https://godoc.org/github.com/k8sp/auto-install?status.svg)](https://godoc.org/github.com/k8sp/auto-install)

This repo includes

- `config`: Go structs that correspond to a YAML file that describes a Kubernetes cluster and a bootstrapper server,
- `bootstrapper`: a Go program that is supposed to be copied to the bootstrapper server and run as root, so to install and configure the bootstrapper server, and
- `cloud-config-server`: a Go HTTP server that generates cloud-config file for each node identified by their MAC addresses in the Kuberenetes cluster.

Both `bootstrapper` and `cloud-config-server` take the YAML cluster description file as input.

