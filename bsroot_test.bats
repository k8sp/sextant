#!/usr/bin/env bats

BSROOT=/tmp/bsroot

if [[ ! -f ./bsroot_lib.bash ]]; then
    echo "Please run bsroot_test.bats from the sextant directory, "
    echo "otherwise, bats would prevents us from finding bsroot_lib.bash"
fi
SEXTANT_DIR=$PWD
source $SEXTANT_DIR/bsroot_lib.bash

setup() {
    echo "setup ${BATS_TEST_NAME} ..." >> /tmp/bsroot_test_bats.log
}

teardown() {
    echo "teardown ${BATS_TEST_NAME} ..." >> /tmp/bsroot_test_bats.log
}

@test "check prerequisites" {
    check_prerequisites
}

@test "download pxe images" {
    download_pxe_images $BSROOT

    [ -d $BSROOT ]
    [ -d $BSROOT/tftpboot ]
    [ -f $BSROOT/tftpboot/pxelinux.0 ]
    [ -f $BSROOT/tftpboot/vesamenu.c32 ]
    [ -f $BSROOT/tftpboot/ldlinux.c32 ]
    [ -f $BSROOT/tftpboot/coreos_production_pxe.vmlinuz ]
    [ -f $BSROOT/tftpboot/coreos_production_pxe_image.cpio.gz ]
}

@test "generate PXE config" {
    local BS_IP="12.34.56.78"
    generate_pxe_config $BSROOT $BS_IP

    [ -f $BSROOT/tftpboot/pxelinux.cfg/default ]
    grep $BS_IP $BSROOT/tftpboot/pxelinux.cfg/default
}

@test "generate dnsmasq config" {
    generate_dnsmasq_config $BSROOT

    [ -f $BSROOT/config/dnsmasq.conf ]
    # TODO(yi): generate_dnsmasq_config is pretty hacky and not customizable yet.
}

@test "generate registry config" {
    generate_registry_config $BSROOT

    [ -f $BSROOT/config/registry.yml ]
    [ -d $BSROOT/registry_data ]
    # TODO(yi): Need more tests here.
}

@test "prepare cc server contents" {
    local BS_IP="12.34.56.78"
    local CLUSTER_DESC=$SEXTANT_DIR/cloud-config-server/template/unisound-ailab/build_config.yml
    prepare_cc_server_contents $BSROOT $CLUSTER_DESC $SEXTANT_DIR $BS_IP

    [ -f $BSROOT/html/static/kubelet ]
    [ -f $BSROOT/kubectl ]
    [ -f $BSROOT/html/static/setup-network-environment-1.0.1 ]
    [ -f $BSROOT/config/cloud-config.template ]
    [ -f $BSROOT/config/cluster-desc.yml ]
    [ -f $BSROOT/config/ingress.template ]
    [ -f $BSROOT/config/skydns.template ]
    [ -f $BSROOT/html/static/cloud-config/install.sh ]
    grep $BS_IP $BSROOT/html/static/cloud-config/install.sh
    [ -L $BSROOT/html/static/current ]
    [ -f $BSROOT/html/static/current/coreos_production_image.bin.bz2 ]
}

@test "download k8s images" {
    download_k8s_images $BSROOT $SEXTANT_DIR/cloud-config-server/template/unisound-ailab/build_config.yml $SEXTANT_DIR
}
