#!/usr/bin/env bash

# bsroot.bash creates the $PWD/bsroot directory, which is supposed to be
# scp-ed to the bootstrapper server as /bsroot.

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    echo "Usage: bsroot.bash cluster-desc.yml [./bsroot]"
    exit 1
fi

# Remember fullpaths, so that it is not required to run bsroot.bash from its local Git repo.
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

SEXTANT_DIR=$(realpath $(dirname $0))
CLUSTER_DESC=$(realpath $1)

BS_IP=`grep "bootstrapper:" $CLUSTER_DESC | awk '{print $2}' | sed 's/ //g'`
if [[ "$?" -ne 0 ||  "$BS_IP" == "" ]]; then
    echo "Failed parsing cluster-desc file $CLUSTER_DESC for bootstrapper IP".
    exit 1
fi
echo "Using bootstrapper server IP $BS_IP"

if [[ "$#" == "2" ]]; then
    BSROOT=$2
else
    BSROOT=$PWD/bsroot
fi

if [[ -d $BSROOT ]]; then
    echo "$BSROOT already exists.  Overwrite without removing it."
fi

source $SEXTANT_DIR/bsroot_lib.bash

check_prerequisites
download_pxe_images $BSROOT
generate_pxe_config $BSROOT $BS_IP
generate_dnsmasq_config $BSROOT
generate_registry_config $BSROOT
prepare_cc_server_contents $BSROOT $SEXTANT_DIR $BS_IP
download_k8s_images $BSROOT $CLUSTER_DESC $SEXTANT_DIR
generate_tls_assets $BSROOT
