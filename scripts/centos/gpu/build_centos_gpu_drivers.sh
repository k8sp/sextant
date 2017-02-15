#!/usr/bin/env bash
#
# Build NVIDIA drivers on CentOS
#
DRIVER_VERSION=$1
HTTP_GPU_DIR=$2
DRIVER_ARCHIVE=NVIDIA-Linux-x86_64-${DRIVER_VERSION}

download_install_nvidia_gpu_drivers(){
  echo "Downloading NVIDIA Linux drivers version ${DRIVER_VERSION}"
  wget --quiet -c -N ${HTTP_GPU_DIR}/${DRIVER_ARCHIVE}.run
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
