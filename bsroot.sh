#!/usr/bin/env bash

# bsroot.sh doing the preparing stage of running the sextant bootstrapper.
#
# Usage: bsroot.sh <cluster-desc.yml> [\$SEXTANT_DIR/bsroot]
#
#
# Things include:
# 1. Create a "bsroot" directory, download contents that is needed:
#      1) PXE images
#      2) Linux images, currently CoreOS and CentOS7
#      3) docker images that is needed to deploy kubernetes and ceph
#      4) NVIDIA gpu drivers
# 2. Compile cloud-config-server binaries in a docker container
# 3. Generate configurations accroding to 'cluster-desc.yaml'
# 4. Generate root CA and api-server certs under 'ssl/'.
# 4. Package the bootstrapper as a docker image. Put dnsmasq, docker registry
#    cloud-config-server and scripts needed into one image.
# ***** Important *****
# bsroot.sh considers the situation of a "offline cluster", which is not able to
# connect to the internet directly. So all the images/files must be prepared
# under generated "./bsroot" directory. Copy this directory to the "real"
# bootstrap server when the bootstrapper server is "offline". Or, you can run
# bsroot.sh directly on the bootstrap server.

SEXTANT_ROOT=${PWD}
source $SEXTANT_ROOT/scripts/common.sh

check_prerequisites
check_cluster_desc_file


echo "Install OS: ${cluster_desc_os_name}"
if [[ $cluster_desc_os_name == "CentOS" ]]; then
    source $SEXTANT_DIR/scripts/centos.sh
    download_centos_images
    generate_pxe_centos_config
    generate_kickstart_config
    generate_post_provision_script
    generate_post_nochroot_provision_script
    generate_post_cloudinit_script
    generate_rpmrepo_config
    download_centos_gpu_drivers
elif [[ $cluster_desc_os_name == "CoreOS" ]]; then
    source $SEXTANT_DIR/scripts/coreos.sh
    check_coreos_version
    download_pxe_images
    generate_pxe_config
    build_coreos_nvidia_gpu_drivers
else
    echo "Unsupport OS: ${cluster_desc_os_name}"
    exit -1
fi

generate_registry_config
prepare_cc_server_contents
download_k8s_images
build_bootstrapper_image
generate_tls_assets
prepare_setup_kubectl
generate_addons_config
