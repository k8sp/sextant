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
CLOUD_CONFIG_TEMPLATE=$SEXTANT_DIR/cloud-config-server/template/cloud-config.template
INSTALL_CEPH_SCRIPT_DIR=$SEXTANT_DIR/install-ceph
CLUSTER_DESC=$(realpath $1)

# Check sextant dir
if [[ "$SEXTANT_DIR" != "$GOPATH/src/github.com/k8sp/sextant" ]]; then
    echo "\$SEXTANT_DIR=$SEXTANT_DIR differs from $GOPATH/src/github.com/k8sp/sextant."
    echo "Please set GOPATH environment variable and use 'go get' to retrieve sextant."
    exit 1
fi

if [[ "$#" == 2 ]]; then
    BSROOT=$2
else
    BSROOT=$SEXTANT_DIR/bsroot
fi

if [[ -d $BSROOT ]]; then
    echo "$BSROOT already exists. Overwrite without removing it."
else
    mkdir -p $BSROOT
fi

BS_IP=`grep "bootstrapper:" $CLUSTER_DESC | awk '{print $2}' | sed 's/ //g'`
if [[ "$?" -ne 0 ||  "$BS_IP" == "" ]]; then
    echo "Failed parsing cluster-desc file $CLUSTER_DESC for bootstrapper IP".
    exit 1
fi
echo "Using bootstrapper server IP $BS_IP"

KUBE_MASTER_HOSTNAME=`head -n $(grep -n 'kube_master\s*:\s*y' $CLUSTER_DESC | cut -d: -f1) $CLUSTER_DESC | grep mac: | tail | grep -o '..:..:..:..:..:..' | tr ':' '-'`
if [[ "$?" -ne 0 || "$KUBE_MASTER_HOSTNAME" == "" ]]; then
  echo "The cluster-desc file should container kube-master node."
  exit 1
fi

HYPERKUBE_VERSION=`grep "hyperkube:" $CLUSTER_DESC | grep -o '".*hyperkube.*:.*"' | sed 's/".*://; s/"//'`


source $SEXTANT_DIR/bsroot_lib.bash


check_prerequisites() {
    printf "Checking prerequisites ... "
    err=0
    for tool in wget tar gpg docker tr go make; do
        command -v $tool >/dev/null 2>&1 || { echo "Install $tool before run this script"; err=1; }
    done
    if [[ $err -ne 0 ]]; then
        exit 1
    fi
    echo "Done"
}


download_pxe_images() {
    mkdir -p $BSROOT/tftpboot

    printf "Downloading syslinux ... "
    wget --quiet -c -N -P $BSROOT/tftpboot https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz || { echo "Failed"; exit 1; }
    cd $BSROOT/tftpboot
    tar xzf syslinux-6.03.tar.gz || { echo "Failed"; exit 1; }
    cp syslinux-6.03/bios/core/pxelinux.0 $BSROOT/tftpboot || { echo "Failed"; exit 1; }
    cp syslinux-6.03/bios/com32/menu/vesamenu.c32 $BSROOT/tftpboot || { echo "Failed"; exit 1; }
    cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 $BSROOT/tftpboot || { echo "Failed"; exit 1; }
    rm -rf syslinux-6.03 || { echo "Failed"; exit 1; } # Clean the untarred.
    echo "Done"

    printf "Importing CoreOS signing key ... "
    wget --quiet -c -N -P $BSROOT/tftpboot https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc || { echo "Failed"; exit 1; }
    gpg --import --keyid-format LONG $BSROOT/tftpboot/CoreOS_Image_Signing_Key.asc > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Downloading CoreOS PXE vmlinuz image ... "
    wget --quiet -c -N -P $BSROOT/tftpboot https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz || { echo "Failed"; exit 1; }
    wget --quiet -c -N -P $BSROOT/tftpboot https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz.sig || { echo "Failed"; exit 1; }
    cd $BSROOT/tftpboot
    gpg --verify coreos_production_pxe.vmlinuz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Downloading CoreOS PXE CPIO image ... "
    wget --quiet -c -N -P $BSROOT/tftpboot https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz || { echo "Failed"; exit 1; }
    wget --quiet -c -N -P $BSROOT/tftpboot https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz.sig || { echo "Failed"; exit 1; }
    gpg --verify coreos_production_pxe_image.cpio.gz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"
}


generate_pxe_config() {
    printf "Generating pxelinux.cfg ... "
    mkdir -p $BSROOT/tftpboot/pxelinux.cfg
    cat > $BSROOT/tftpboot/pxelinux.cfg/default <<EOF
default coreos

label coreos
  kernel coreos_production_pxe.vmlinuz
  append initrd=coreos_production_pxe_image.cpio.gz cloud-config-url=http://$BS_IP/static/cloud-config/install.sh coreos.autologin
EOF
    echo "Done"
}


generate_registry_config() {
    printf "Generating Docker registry config file ... "
    mkdir -p $BSROOT/registry_data
    [ ! -d $BSROOT/config ] && mkdir -p $BSROOT/config
    cat > $BSROOT/config/registry.yml <<EOF
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /bsroot/registry_data
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
  tls:
    certificate: /bsroot/tls/bootstrapper.crt
    key: /bsroot/tls/bootstrapper.key
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
    echo "Done"
}


prepare_cc_server_contents() {
    printf "Generating Ceph installation scripts..."
    mkdir -p $BSROOT/html/static/ceph
    # update install-mon.sh and set OSD_JOURNAL_SIZE
    OSD_JOURNAL_SIZE=$cluster_desc_ceph_osd_journal_size
    # update ceph install scripts to use image configured in cluster-desc.yml
    CEPH_DAEMON_IMAGE=$(echo $cluster_desc_images_ceph | sed -e 's/[\/&]/\\&/g')
    printf "$CEPH_DAEMON_IMAGE..."
    sed "s/ceph\/daemon/$CEPH_DAEMON_IMAGE/g" $INSTALL_CEPH_SCRIPT_DIR/install-mon.sh | \
        sed "s/OSD_JOURNAL_SIZE=<JOURNAL_SIZE>/OSD_JOURNAL_SIZE=$OSD_JOURNAL_SIZE/g" \
        > $BSROOT/html/static/ceph/install-mon.sh || { echo "install-mon Failed"; exit 1; }

    sed "s/ceph\/daemon/$CEPH_DAEMON_IMAGE/g" $INSTALL_CEPH_SCRIPT_DIR/install-osd.sh \
        > $BSROOT/html/static/ceph/install-osd.sh || { echo "install-osd Failed"; exit 1; }
    echo "Done"

    mkdir -p $BSROOT/html/static/cloud-config

    # Fetch release binary tarball from github accroding to the versions
    # defined in "cluster-desc.yml"
    hyperkube_version=`grep "hyperkube:" $CLUSTER_DESC | grep -o '".*hyperkube.*:.*"' | sed 's/".*://; s/"//'`
    printf "Downloading and kubelet and kubectl of release ${hyperkube_version} ... "
    wget --quiet -c -N -O $BSROOT/html/static/kubelet https://storage.googleapis.com/kubernetes-release/release/$hyperkube_version/bin/linux/amd64/kubelet
    chmod +x $BSROOT/html/static/kubelet
    echo "Done"

    # setup-network-environment will fetch the default system IP infomation
    # when using cloud-config file to initiate a kubernetes cluster node
    printf "Downloading setup-network-environment file ... "
    wget --quiet -c -N -O $BSROOT/html/static/setup-network-environment-1.0.1 https://github.com/kelseyhightower/setup-network-environment/releases/download/1.0.1/setup-network-environment || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Copying cloud-config template and cluster-desc.yml ... "
    cp $CLOUD_CONFIG_TEMPLATE $BSROOT/config/ || { echo "Failed"; exit 1; }
    cp $CLUSTER_DESC $BSROOT/config/cluster-desc.yml || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Copying bsroot_lib.bash ... "
    cp $SEXTANT_DIR/bsroot_lib.bash $BSROOT/ || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Generating install.sh ... "
    echo "#!/bin/bash" > $BSROOT/html/static/cloud-config/install.sh
    if grep "zap_and_start_osd: y" $CLUSTER_DESC > /dev/null; then
    cat >> $BSROOT/html/static/cloud-config/install.sh <<EOF
#Obtain devices
devices=\$(lsblk -l |awk '\$6=="disk"{print \$1}')
# Zap all devices
# NOTICE: dd zero to device mbr will not affect parted printed table,
#         so use parted to remove the part tables
for d in \$devices
do
  for v_partition in \$(parted -s /dev/\${d} print|awk '/^ / {print \$1}')
  do
     parted -s /dev/\${d} rm \${v_partition}
  done
done
EOF
    fi
    cat >> $BSROOT/html/static/cloud-config/install.sh <<EOF
# FIXME: default to install coreos on /dev/sda
default_iface=\$(awk '\$2 == 00000000 { print \$1  }' /proc/net/route | uniq)

printf "Default interface: \${default_iface}\n"
default_iface=\`echo \${default_iface} | awk '{ print \$1 }'\`

mac_addr=\`ip addr show dev \${default_iface} | awk '\$1 ~ /^link\// { print \$2 }'\`
printf "Interface: \${default_iface} MAC address: \${mac_addr}\n"

wget -O \${mac_addr}.yml http://$BS_IP/cloud-config/\${mac_addr}
sudo coreos-install -d /dev/sda -c \${mac_addr}.yml -b http://$BS_IP/static -V current && sudo reboot
EOF
    echo "Done"

    printf "Checking new CoreOS version ... "
    VERSION=$(curl -s https://stable.release.core-os.net/amd64-usr/current/version.txt | grep 'COREOS_VERSION=' | cut -f 2 -d '=')
    if [[ $VERSION == "" ]]; then
        echo "Failed"; exit 1;
    fi
    echo "Done"

    printf "Updating CoreOS images ... "
    if [[ ! -d $BSROOT/html/static/$VERSION ]]; then
        mkdir -p $BSROOT/html/static/$VERSION
    fi

    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://stable.release.core-os.net/amd64-usr/current/version.txt
    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://stable.release.core-os.net/amd64-usr/current/coreos_production_image.bin.bz2 || { echo "Failed"; exit 1; }
    wget --quiet -c -N -P $BSROOT/html/static/$VERSION https://stable.release.core-os.net/amd64-usr/current/coreos_production_image.bin.bz2.sig || { echo "Failed"; exit 1; }
    cd $BSROOT/html/static/$VERSION
    gpg --verify coreos_production_image.bin.bz2.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    cd $BSROOT/html/static
    ln -sf ./$VERSION current || { echo "Failed"; exit 1; }
    echo "Done"
}



build_bootstrapper_image() {
    local THIS_OS=$(go env | grep 'GOOS=' | cut -f 2 -d '=' | sed 's/"//g')
    local THIS_ARCH=$(go env | grep 'GOARCH=' | cut -f 2 -d '=' | sed 's/"//g')

    # target binary arch is amd64, and build in docker image will always amd64
    printf "Cross-compiling Sextant Go programs ... "
    docker rm sextant_build > /dev/null 2>&1
    docker run --name=sextant_build \
            --volume $SEXTANT_DIR:/go/src/github.com/k8sp/sextant \
            --volume $SEXTANT_DIR/docker:/go/bin \
            -e CGO_ENABLED=0 \
            -e GOOS=linux \
            -e GOARCH=amd64 \
            golang:wheezy \
            go get github.com/k8sp/sextant/cloud-config-server github.com/k8sp/sextant/addons \
            || { echo "Build sextant failed..."; exit 1; }
    docker rm sextant_build > /dev/null 2>&1
    echo "Done"

    # FIXME: build addon for this arch, only support MacOS and linux
    printf "Compiling addons for local machine ... "
    if [[ $THIS_OS == '"linux"' && $THIS_ARCH == '"amd64"' ]]; then
      ADDONS=$SEXTANT_DIR/docker/addons
    else
      docker run --name=sextant_build \
              --volume $SEXTANT_DIR:/go/src/github.com/k8sp/sextant \
              --volume $SEXTANT_DIR/docker:/go/bin \
              -e CGO_ENABLED=0 \
              -e GOOS=$THIS_OS \
              -e GOARCH=$THIS_ARCH \
              golang:wheezy \
              go get github.com/k8sp/sextant/addons \
              || { echo "Build addon for local arch failed..."; exit 1; }
      ADDONS=$SEXTANT_DIR/docker/${THIS_OS}_${THIS_ARCH}/addons
    fi
    echo "Done"

    printf "Cross-compiling Docker registry ... "
    docker rm registry_build > /dev/null 2>&1
    docker run --name=registry_build \
            --volume $SEXTANT_DIR/docker:/go/bin \
            -e CGO_ENABLED=0 \
            -e GOOS=linux \
            -e GOARCH=amd64 \
            golang:wheezy \
            sh -c "go get -u -d github.com/docker/distribution/cmd/registry && cd /go/src/github.com/docker/distribution && make PREFIX=/go clean /go/bin/registry >/dev/null" \
            || { echo "Complie Docker registry failed..."; exit 1; }
    docker rm registry_build > /dev/null 2>&1
    echo "Done"

    printf "Building bootstrapper image ... "
    cd $SEXTANT_DIR/docker
    docker build -t bootstrapper . > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    docker save bootstrapper:latest > $BSROOT/bootstrapper.tar || { echo "Failed"; exit 1; }
    # NOTE: we need to run docker load on the bootstrapper server
    # to load these saved images.
    echo "Done"

    cp $SEXTANT_DIR/start_bootstrapper_container.sh \
       $BSROOT/start_bootstrapper_container.sh 2>&1 || { echo "Failed"; exit 1; }
    chmod +x $BSROOT/start_bootstrapper_container.sh
}


download_k8s_images() {
    for DOCKER_IMAGE in $(set | grep '^cluster_desc_images_' | grep -o '".*"' | sed 's/"//g'); do
        # NOTE: if we updated remote image but didn't update its tag,
        # the following lines wouldn't pull because there is a local
        # image with the same tag.
        if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep $DOCKER_IMAGE > /dev/null; then
            printf "Pulling image ${DOCKER_IMAGE} ... "
            docker pull $DOCKER_IMAGE > /dev/null 2>&1 || { echo "Failed"; exit 1; }
            echo "Done"
        fi

        local DOCKER_TAR_FILE=$BSROOT/`echo $DOCKER_IMAGE.tar | sed "s/:/_/g" |awk -F'/' '{print $2}'`
        if [[ ! -f $DOCKER_TAR_FILE ]]; then
            printf "Exporting $DOCKER_TAR_FILE ... "
            docker save $DOCKER_IMAGE > $DOCKER_TAR_FILE.progress || { echo "Failed"; exit 1; }
            mv $DOCKER_TAR_FILE.progress $DOCKER_TAR_FILE
            echo "Done"
        fi
    done
}


generate_tls_assets() {
    mkdir -p $BSROOT/tls
    cd $BSROOT/tls
    rm -rf $BSROOT/tls/*

    printf "Generating CA TLS assets ... "
    openssl genrsa -out ca-key.pem 2048 > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=kube-ca"  > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Generating bootstrapper TLS assets ... "
    openssl genrsa -out bootstrapper.key 2048 > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    openssl req -new -key bootstrapper.key -out bootstrapper.csr -subj "/CN=bootstrapper" > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    openssl x509 -req -in bootstrapper.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out bootstrapper.crt -days 365 > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"
}

prepare_setup_kubectl() {
  printf "Preparing setup kubectl ... "
  sed "s/<KUBE_MASTER_HOSTNAME>/$KUBE_MASTER_HOSTNAME/g" $SEXTANT_DIR/setup-kubectl.bash | \
    sed "s/<HYPERKUBE_VERSION>/$HYPERKUBE_VERSION/g" \
    > $BSROOT/setup_kubectl.bash 2>&1 || { echo "Prepare setup kubectl failed."; exit 1; }
  chmod +x $BSROOT/setup_kubectl.bash
  echo "Done"
}

generate_addons_config() {
    printf "Generating configuration files ..."
    $ADDONS -cluster-desc-file $CLUSTER_DESC \
        -template-file $SEXTANT_DIR/addons/template/ingress.template \
        -config-file $BSROOT/html/static/ingress.yaml || \
        { echo 'Failed to generate ingress.yaml !' ; exit 1; }

    $ADDONS -cluster-desc-file $CLUSTER_DESC \
        -template-file $SEXTANT_DIR/addons/template/skydns.template \
        -config-file $BSROOT/html/static/skydns.yaml || \
        { echo 'Failed to generate skydns.yaml !' ; exit 1; }

    $ADDONS -cluster-desc-file $CLUSTER_DESC \
        -template-file $SEXTANT_DIR/addons/template/skydns-service.template \
        -config-file $BSROOT/html/static/skydns-service.yaml || \
        { echo 'Failed to generate skydns-service.yaml !' ; exit 1; }

    $ADDONS -cluster-desc-file $CLUSTER_DESC \
        -template-file $SEXTANT_DIR/addons/template/dnsmasq.conf.template \
        -config-file $BSROOT/config/dnsmasq.conf || \
        { echo 'Failed to generate dnsmasq.conf !' ; exit 1; }

    echo "Done"
}

check_prerequisites
load_yaml $CLUSTER_DESC cluster_desc_
download_pxe_images
generate_pxe_config
generate_registry_config
prepare_cc_server_contents
download_k8s_images
build_bootstrapper_image
generate_tls_assets
prepare_setup_kubectl
generate_addons_config
