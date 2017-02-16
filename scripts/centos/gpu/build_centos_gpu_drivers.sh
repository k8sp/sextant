#!/usr/bin/env bash
#
# Build NVIDIA drivers on CentOS
#

set -xe

DRIVER_VERSION=$1
HTTP_GPU_DIR=$2
CENTOS_VERSION=$3
DRIVER_ARCHIVE=NVIDIA-Linux-x86_64-${DRIVER_VERSION}
DRIVER_ARCHIVE_PATH=${PWD}/nvidia_installers/${DRIVER_ARCHIVE}.run
WORK_DIR=${PWD}/run_files/${CENTOS_VERSION}
ARTIFACT_DIR=${WORK_DIR}/${DRIVER_ARCHIVE}
NVIDIA_DIR=/usr/local/nvidia
NVIDIA_BIN_DIR=/usr/local/nvidia/bin
NVIDIA_LIB_DIR=/usr/local/nvidia/lib64
TOOLS="nvidia-debugdump nvidia-cuda-mps-control nvidia-xconfig nvidia-modprobe nvidia-smi nvidia-cuda-mps-server nvidia-persistenced nvidia-settings"

download_nvidia_gpu_drivers(){
  if [ ! -f ${DRIVER_ARCHIVE_PATH} ]
  then
    echo Downloading NVIDIA Linux drivers version ${DRIVER_VERSION}
    mkdir -p nvidia_installers
    wget --quiet -c -N -P nvidia_installers ${HTTP_GPU_DIR}/${DRIVER_ARCHIVE}.run || { echo "Failed"; exit 1; }
  fi
}

build_lib_and_ko() {
  mkdir -p ${WORK_DIR}
  cp -ul ${DRIVER_ARCHIVE_PATH} ${WORK_DIR}
  pushd ${WORK_DIR}
  chmod +x ${DRIVER_ARCHIVE}.run
  rm -Rf ./${DRIVER_ARCHIVE}
  ./${DRIVER_ARCHIVE}.run -x
  cd ${DRIVER_ARCHIVE}
  ./nvidia-installer -s
  popd
  # Create archives with no paths
  tar -C ${ARTIFACT_DIR} -cvj $(basename -a ${ARTIFACT_DIR}/*.so.*) > libraries-${DRIVER_VERSION}.tar.bz2
  tar -C ${ARTIFACT_DIR} -cvj ${TOOLS} > tools-${DRIVER_VERSION}.tar.bz2
}

install_lib_and_ko() {
  mkdir -p ${NVIDIA_DIR}
    mkdir -p ${NVIDIA_BIN_DIR}
    cp ./tools-${DRIVER_VERSION}.tar.bz2 ${NVIDIA_BIN_DIR}
    pushd ${NVIDIA_BIN_DIR}
    tar -xjf ./tools-${DRIVER_VERSION}.tar.bz2
    popd
    mkdir -p ${NVIDIA_LIB_DIR}
    cp ./libraries-${DRIVER_VERSION}.tar.bz2 ${NVIDIA_LIB_DIR}
    pushd ${NVIDIA_LIB_DIR}
    for LIBRARY_NAME in libcuda libGLESv1_CM \
      libGL libEGL \
      libnvidia-cfg libnvidia-encode libnvidia-fbc \
      libnvidia-ifr libnvidia-ml libnvidia-opencl \
      libnvcuvid libvdpau
    do
      ln -sf ${LIBRARY_NAME}.so.${DRIVER_VERSION} ${LIBRARY_NAME}.so.1
      ln -sf ${LIBRARY_NAME}.so.1 ${LIBRARY_NAME}.so
    done
    ln -sf libOpenCL.so.1.0.0 libOpenCL.so.1
    ln -sf libOpenCL.so.1 libOpenCL.so
    ln -sf libGLESv2.so.${DRIVER_VERSION} libGLESv2.so.2
    ln -sf libGLESv2.so.2 libGLESv2.so
    ln -sf libvdpau_nvidia.so.${DRIVER_VERSION} libvdpau_nvidia.so
    ln -sf libvdpau_trace.so.${DRIVER_VERSION} libvdpau_trace.so
    tar -xjf ./libraries-${DRIVER_VERSION}.tar.bz2
}

disable_nouveau() {
    cat > /etc/modprobe.d/nvidia-installer-disable-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
/sbin/modprobe -r nouveau

}


disable_nouveau
download_nvidia_gpu_drivers
build_lib_and_ko
install_lib_and_ko

wget -P /root ${HTTP_GPU_DIR}/nvidia-gpu-mkdev.sh
/bin/bash /root/nvidia-gpu-mkdev.sh
echo "/bin/bash /root/nvidia-gpu-mkdev.sh" >>/etc/rc.local
chmod +x /etc/rc.local
