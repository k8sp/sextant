#!/bin/sh

ARTIFACT_DIR=$1
VERSION=$2
COMBINED_VERSION=$3

TOOLS="nvidia-debugdump nvidia-cuda-mps-control nvidia-xconfig nvidia-modprobe nvidia-smi nvidia-cuda-mps-server
nvidia-persistenced nvidia-settings"

# Create archives with no paths
tar -C ${ARTIFACT_DIR} -cvj $(basename -a ${ARTIFACT_DIR}/*.so.*) > libraries-${VERSION}.tar.bz2
tar -C ${ARTIFACT_DIR} -cvj ${TOOLS} > tools-${VERSION}.tar.bz2
tar -C ${ARTIFACT_DIR}/kernel -cvj $(basename -a ${ARTIFACT_DIR}/kernel/*.ko) > modules-${COMBINED_VERSION}.tar.bz2
