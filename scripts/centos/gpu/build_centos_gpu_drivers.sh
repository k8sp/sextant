#!/usr/bin/env bash
#
# Build NVIDIA drivers on CentOS
#
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

download_install_nvidia_gpu_drivers(){
  if [ ! -f ${DRIVER_ARCHIVE_PATH} ]
  then
    echo Downloading NVIDIA Linux drivers version ${DRIVER_VERSION}
    wget --quiet -c -N ${HTTP_GPU_DIR}/${DRIVER_ARCHIVE}.run || { echo "Failed"; exit 1; }
  fi
  chmod +x ${DRIVER_ARCHIVE}.run
  ./${DRIVER_ARCHIVE}.run -s
}

disable_nouveau() {
    cat > /etc/modprobe.d/nvidia-installer-disable-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
/sbin/modprobe -r nouveau

}


disable_nouveau
download_install_nvidia_gpu_drivers

wget -P /root ${HTTP_GPU_DIR}/nvidia-gpu-mkdev.sh
/bin/bash /root/nvidia-gpu-mkdev.sh
echo "/bin/bash /root/nvidia-gpu-mkdev.sh" >>/etc/rc.local
chmod +x /etc/rc.local
