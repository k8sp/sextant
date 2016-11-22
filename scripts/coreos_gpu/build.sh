#!/bin/bash
#
# Build NVIDIA drivers for a given CoreOS version
#

SCRIPTS_DIR=$1
WORK_DIR=$2
DRIVER_VERSION=${3:-367.57}
COREOS_TRACK=${4:-stable}
COREOS_VERSION=${5:-1122.2.0}

DRIVER_ARCHIVE=NVIDIA-Linux-x86_64-${DRIVER_VERSION}
DRIVER_ARCHIVE_PATH=${WORK_DIR}/nvidia_installers
DEV_CONTAINER=coreos_developer_container.bin.${COREOS_VERSION}
PKG_DIR=${WORK_DIR}/pkg/run_files/${COREOS_VERSION}

function finish {
  rm -Rf tmp
}

trap finish exit

mkdir -p $WORK_DIR
cd $WORK_DIR

cp ${SCRIPTS_DIR}/_container_build.sh ${WORK_DIR}
cp ${SCRIPTS_DIR}/_export.sh ${WORK_DIR}

echo "Downloading CoreOS ${COREOS_TRACK} developer image ${COREOS_VERSION}"
SITE=${COREOS_TRACK}.release.core-os.net/amd64-usr
wget -c -N https://${SITE}/${COREOS_VERSION}/coreos_developer_container.bin.bz2 \
  -O ${DEV_CONTAINER}.bz2 || { echo "Failed"; exit 1; }

echo "Decompressing"
#bunzip2 -qfk ${DEV_CONTAINER}.bz2 || { echo "Failed"; exit 1; }


echo "Downloading NVIDIA Linux drivers version ${DRIVER_VERSION}"
mkdir -p ${DRIVER_ARCHIVE_PATH}
SITE=us.download.nvidia.com/XFree86/Linux-x86_64
wget -c -N http://${SITE}/${DRIVER_VERSION}/${DRIVER_ARCHIVE}.run \
  -P ${DRIVER_ARCHIVE_PATH} || { echo "Failed"; exit 1; }

rm -Rf ${WORK_DIR}/tmp
mkdir -p ${WORK_DIR}/tmp ${PKG_DIR}
cp -ul ${DRIVER_ARCHIVE_PATH}/${DRIVER_ARCHIVE}.run ${PKG_DIR}

pushd ${PKG_DIR}
chmod +x ${DRIVER_ARCHIVE}.run
rm -Rf ./${DRIVER_ARCHIVE}
./${DRIVER_ARCHIVE}.run -x -s
popd


echo "sudo systemd-nspawn -i ${DEV_CONTAINER} --share-system \
  --bind=${WORK_DIR}/_container_build.sh:/_container_build.sh \
  --bind=${WORK_DIR}/${PKG_DIR}:/nvidia_installers \
  /bin/bash -x /_container_build.sh ${DRIVER_VERSION}"

sudo systemd-nspawn -i ${DEV_CONTAINER} --share-system \
  --bind=${WORK_DIR}/_container_build.sh:/_container_build.sh \
  --bind=${PKG_DIR}:/nvidia_installers \
  /bin/bash -x /_container_build.sh ${DRIVER_VERSION}

sudo chown -R ${UID}:${GROUPS[0]} ${PKG_DIR}

bash -x ${WORK_DIR}/_export.sh ${PKG_DIR}/*-${DRIVER_VERSION} \
  ${DRIVER_VERSION} ${COREOS_VERSION}-${DRIVER_VERSION}
