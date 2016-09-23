#!/bin/bash

if go install \
      github.com/k8sp/sextant/cloud-config-server \
      github.com/k8sp/sextant/addons; \
then
   cp $GOPATH/bin/{cloud-config-server,addons} .
   docker build -t bootstrapper .
fi
