#!/usr/bin/env bats

if [[ ! -f ./scripts/load_yaml.sh ]]; then
    echo "Please run bsroot_test.bats from the sextant directory, "
    echo "otherwise, bats would prevents us from finding bsroot_lib.bash"
fi
SEXTANT_DIR=$PWD
source $SEXTANT_DIR/scripts/load_yaml.sh

setup() {
    echo "setup ${BATS_TEST_NAME} ..." >> /tmp/bsroot_test_bats.log
}

teardown() {
    echo "teardown ${BATS_TEST_NAME} ..." >> /tmp/bsroot_test_bats.log
}

@test "check prerequisites" {
    check_prerequisites
}

@test "check load_yaml" {
    load_yaml testdata/example.yaml "bsroot_test_"
    [[ $bsroot_test_animal == "cat" ]]
}
