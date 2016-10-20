#!/bin/bash

printf "Cross-compiling Sextant Go programs ... "
rm -f $GOPATH/src/github.com/k8sp/sextant/docker/{cloud-config-server,addons} >/dev/null 2>&1
# FIXME: get dependencies use godep, not script
go get github.com/topicai/candy
go get github.com/wangkuiyi/sh
go get github.com/gorilla/mux
go get gopkg.in/yaml.v2

# CGO_ENABLED=0 builds fully statically-linked
# programs. https://github.com/wangkuiyi/build-statically-linked-go-programs.
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go install \
         github.com/k8sp/sextant/cloud-config-server \
         github.com/k8sp/sextant/addons \
         || { echo "Failed"; exit 1; }
echo "Done"

printf "Cross-compiling Docker registry ... "
rm -f $GOPATH/src/github.com/k8sp/sextant/docker/registry >/dev/null 2>&1
go get -u -d github.com/docker/distribution/cmd/registry \
      && cd $GOPATH/src/github.com/docker/distribution \
      && make CGO_ENABLED=0 GOOS=linux GOARCH=amd64 PREFIX=$GOPATH clean $GOPATH/bin/registry >/dev/null 2>&1\
      || { echo "Failed"; exit 1; }
echo "Done"

