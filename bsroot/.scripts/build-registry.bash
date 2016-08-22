#!/bin/bash

REGISTRY=github.com/docker/distribution/cmd/registry

if [[ $GOPATH == "" ]]; then
    echo "Please install Go and set GOPATH"
    exit -1
fi

if [[ ! -d $GOPATH/src/$REGISTRY ]]; then
    echo "go getting Docker registry ..."
    go get -u $REGISTRY
fi

echo "go install Docker registry ..."
GOOS=linux GOARCH=amd64 go install $REGISTRY
cp $GOPATH/bin/linux_amd64/registry .
