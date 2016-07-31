#!/bin/bash

function DockerBuildAndRun() {
    BASE=$1
    PKG=$2
    TEST=$(echo $PKG | awk  'BEGIN{FS=".";} {print $NF;}').test
	
    echo "FROM $BASE" > $BASE.dockerfile
    echo "COPY . /tmp" >> $BASE.dockerfile
    echo "CMD /tmp/$TEST -indocker" >> $BASE.dockerfile

    docker build -t $BASE$PKG -f $BASE.dockerfile .
    docker run -it $BASE$PKG

    rm $BASE.dockerfile
}

(
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd $DIR
    
    GOOS=linux GOARCH=amd64 go test -c  # Build the dhcp.test binary.
    if [[ $? != 0 ]]; then
	echo "Failed building test binary"
	exit -1
    fi

    PKG=$(go list . | sed 's/\//./g')
    DockerBuildAndRun "ubuntu:14.04" $PKG
    DockerBuildAndRun "centos:7" $PKG
)

