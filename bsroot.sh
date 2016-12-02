#!/usr/bin/env bash

# bsroot.sh creates the $PWD/bsroot directory, which is supposed to be
# scp-ed to the bootstrapper server as /bsroot.
if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    echo "Usage: bsroot.sh <cluster-desc.yml> [\$SEXTANT_DIR/bsroot]"
    exit 1
fi

# Remember fullpaths, so that it is not required to run bsroot.sh from its local Git repo.
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

SEXTANT_DIR=$(dirname $(realpath $0))


source $SEXTANT_DIR/scripts/common.sh
source $SEXTANT_DIR/scripts/bsroot_lib.bash
load_yaml $CLUSTER_DESC cluster_desc_


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
