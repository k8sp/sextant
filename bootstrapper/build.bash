#!/bin/bash

THIS_OS=$(go env | grep 'GOOS=' | cut -f 2 -d '=')
THIS_ARCH=$(go env | grep 'GOARCH=' | cut -f 2 -d '=')

# CGO_ENABLED=0 builds fully statically-linked programs. https://github.com/wangkuiyi/build-statically-linked-go-programs.
# GOOS=linux GOARCH=amd64 cross-compiles and generates Linux 64-bit programs.
if CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go install \
      github.com/k8sp/sextant/cloud-config-server \
      github.com/k8sp/sextant/addons; \
then
   if [[ $THIS_OS != '"linux"' || $THIS_ARCH != '"amd64"' ]]; then
       cp $GOPATH/bin/linux_amd64/{cloud-config-server,addons} .
   else
       cp $GOPATH/bin/{cloud-config-server,addons} .
   fi
   docker build -t bootstrapper .
fi
