#!/bin/bash

(
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    IMG=$(echo $DIR | sed 's/\//./g' | tr [A-Z] [a-z] )

    cd $DIR

    GOOS=linux GOARCH=amd64 go test -c  # Build the dhcp.test binary.
    if [[ $? != 0 ]]; then
	echo "Failed building test binary"
	exit -1
    fi

    docker build -t ubuntu$IMG -f ubuntu.dockerfile .
    docker run -it ubuntu$IMG

    docker build -t centos$IMG -f centos.dockerfile .
    docker run -it centos$IMG
)
