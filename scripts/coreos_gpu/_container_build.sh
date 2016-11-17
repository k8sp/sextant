#!/bin/sh

VERSION=$1
echo Building ${VERSION}

emerge-gitclone

emerge -gKq coreos-sources
cd /usr/src/linux
cp /lib/modules/*-coreos/build/.config .config

make olddefconfig
make modules_prepare

cd /nvidia_installers/NVIDIA-Linux-x86_64-${VERSION}
./nvidia-installer -s -n --kernel-source-path=/usr/src/linux \
  --no-check-for-alternate-installs --no-opengl-files \
  --kernel-install-path=${PWD} --log-file-name=${PWD}/nvidia-installer.log

cat nvidia-installer.log
