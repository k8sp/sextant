#!/bin/bash

function TestInVM() {
    PKG=$1
    VMBOX=$2
    
    if [[ -d in_vm_test ]]; then
	( cd in_vm_test && vagrant destroy)
    fi

    rm -rf in_vm_test
    mkdir in_vm_test
    (
	cd in_vm_test
	vagrant init $VMBOX
	vagrant up
	vagrant scp ../$PKG.test /home/vagrant/
	vagrant ssh -c "sudo /home/vagrant/$PKG.test -indocker"
    )
}

GOOS=linux GOARCH=amd64 go test -c 
if [[ $? != 0 ]]; then
    echo "Failed building test binary"
    exit -1
fi

PKG=$(basename $(go list .))

TestInVM $PKG "ubuntu/trusty64"	
