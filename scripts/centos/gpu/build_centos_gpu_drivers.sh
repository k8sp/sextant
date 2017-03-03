#!/usr/bin/env bash
#
# Build NVIDIA drivers on CentOS
#

set -xe

DRIVER_VERSION=$1
HTTP_GPU_DIR=$2
NVIDIA_RUN_NAME=NVIDIA-Linux-x86_64-${DRIVER_VERSION}
NVIDIA_RUN_FILE=${NVIDIA_RUN_NAME}.run
NVIDIA_DIR=/usr/local/nvidia
NVIDIA_BIN_DIR=${NVIDIA_DIR}/bin
NVIDIA_LIB_DIR=${NVIDIA_DIR}/lib64
LIBS_FILES=libraries-${DRIVER_VERSION}.tar.bz2
TOOLS_FILES=tools-${DRIVER_VERSION}.tar.bz2
TOOLS="nvidia-debugdump nvidia-cuda-mps-control nvidia-xconfig nvidia-modprobe nvidia-smi nvidia-cuda-mps-server nvidia-persistenced nvidia-settings"

build_lib_and_ko() {
  if [ ! -f ${NVIDIA_RUN_FILE} ]
  then
    echo Downloading NVIDIA Linux drivers version ${DRIVER_VERSION}
    wget --quiet -c -N -O ${NVIDIA_RUN_FILE} ${HTTP_GPU_DIR}/${NVIDIA_RUN_FILE}
  fi

  chmod +x ./${NVIDIA_RUN_FILE}
  rm -rf ${NVIDIA_RUN_NAME}
  ./${NVIDIA_RUN_FILE} -x
  ${NVIDIA_RUN_NAME}/nvidia-installer -s
  # Create archives with no paths
  tar -C ${NVIDIA_RUN_NAME} -cvj $(basename -a ${NVIDIA_RUN_NAME}/*.so.*) > $LIBS_FILES
  tar -C ${NVIDIA_RUN_NAME} -cvj ${TOOLS} > $TOOLS_FILES
}

install_lib_and_ko() {
    mkdir -p ${NVIDIA_BIN_DIR}
    tar -xjf $TOOLS_FILES -C ${NVIDIA_BIN_DIR}
    mkdir -p ${NVIDIA_LIB_DIR}
    tar -xjf $LIBS_FILES -C ${NVIDIA_LIB_DIR}

    for LIBRARY_NAME in libcuda libGLESv1_CM \
      libGL libEGL \
      libnvidia-cfg libnvidia-encode libnvidia-fbc \
      libnvidia-ifr libnvidia-ml libnvidia-opencl \
      libnvcuvid libvdpau
    do
      ln -sf $NVIDIA_LIB_DIR/${LIBRARY_NAME}.so.${DRIVER_VERSION} $NVIDIA_LIB_DIR/${LIBRARY_NAME}.so.1
      ln -sf $NVIDIA_LIB_DIR/${LIBRARY_NAME}.so.1 $NVIDIA_LIB_DIR/${LIBRARY_NAME}.so
    done

    ln -sf $NVIDIA_LIB_DIR/libOpenCL.so.1.0.0 $NVIDIA_LIB_DIR/libOpenCL.so.1
    ln -sf $NVIDIA_LIB_DIR/libOpenCL.so.1 $NVIDIA_LIB_DIR/libOpenCL.so
    ln -sf $NVIDIA_LIB_DIR/libGLESv2.so.${DRIVER_VERSION} $NVIDIA_LIB_DIR/libGLESv2.so.2
    ln -sf $NVIDIA_LIB_DIR/libGLESv2.so.2 $NVIDIA_LIB_DIR/libGLESv2.so
    ln -sf $NVIDIA_LIB_DIR/libvdpau_nvidia.so.${DRIVER_VERSION} $NVIDIA_LIB_DIR/libvdpau_nvidia.so
    ln -sf $NVIDIA_LIB_DIR/libvdpau_trace.so.${DRIVER_VERSION} $NVIDIA_LIB_DIR/libvdpau_trace.so
}

disable_nouveau() {
    cat > /etc/modprobe.d/nvidia-installer-disable-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
/sbin/modprobe -r nouveau

}


disable_nouveau
build_lib_and_ko
install_lib_and_ko

wget -P /root ${HTTP_GPU_DIR}/nvidia-gpu-mkdev.sh
/bin/bash /root/nvidia-gpu-mkdev.sh
echo "/bin/bash /root/nvidia-gpu-mkdev.sh" >>/etc/rc.local
chmod +x /etc/rc.local
