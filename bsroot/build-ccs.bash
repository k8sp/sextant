#!/bin/bash

CCS=github.com/k8sp/auto-install/cloud-config-server

if [[ ! -d $GOPATH/src/$CCS ]]; then
    echo "go getting cloud-config-server ..."
    go get -u $CCS
fi

echo "go install cloud-config-server ..."
GOOS=linux GOARCH=amd64 go install $CCS
cp $GOPATH/bin/linux_amd64/cloud-config-server .
