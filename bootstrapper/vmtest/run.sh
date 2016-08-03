#!/bin/bash

function TestInVM() {
    PKG=$1
    VMBOX=$2
    
    if [[ -d vm ]]; then
	( cd vm && vagrant destroy -f)
    fi

    rm -rf vm
    mkdir vm
    (
	cd vm
	vagrant init $VMBOX
	vagrant up
	vagrant scp ../$PKG.test /home/vagrant/
	vagrant ssh -c "sudo /home/vagrant/$PKG.test -test.invm"
    )
}

GOOS=linux GOARCH=amd64 go test -c 
if [[ $? != 0 ]]; then
    echo "Failed building test binary"
    exit -1
fi

PKG=$(basename $(go list .))

TestInVM $PKG "ubuntu/trusty64"
TestInVM $PKG "centos/7"

(
    cd vm
    vagrant destroy -f
)
rm -rf vm
