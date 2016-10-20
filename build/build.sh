#!/bin/bash

SEXTANT_ROOT=$(dirname "$PWD")
printf "Building sextant_build_image..."
# build the sextant_build_image
docker build -t sextant_build_image $SEXTANT_ROOT/build/build_image > /dev/null 2>&1 || { echo "build sextant_build_image failed"; exit 1;}
echo "Done"

THIS_OS=$(go env | grep 'GOOS=' | cut -f 2 -d '=')
THIS_ARCH=$(go env | grep 'GOARCH=' | cut -f 2 -d '=')

docker rm sextant_build > /dev/null 2>&1

echo $SEXTANT_ROOT
docker run -it --name=sextant_build \
	--volume $SEXTANT_ROOT:/go/src/github.com/k8sp/sextant \
	sextant_build_image \
	/bin/bash /go/src/github.com/k8sp/sextant/build/build_binaries.sh \
        || { echo "build failed..."; exit 1; }

docker cp sextant_build:/go/bin/cloud-config-server $SEXTANT_ROOT/docker/
docker cp sextant_build:/go/bin/addons $SEXTANT_ROOT/docker/
docker cp sextant_build:/go/bin/registry $SEXTANT_ROOT/docker/
docker rm sextant_build > /dev/null 2>&1
