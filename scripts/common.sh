#!/usr/bin/env bash

# Common utilities, variables and checks for all build scripts.
set -o errexit
set -o nounset
set -o pipefail

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    echo "Usage: bsroot.sh <cluster-desc.yml> [\$SEXTANT_DIR/bsroot]"
    exit 1
fi

# Remember fullpaths, so that it is not required to run bsroot.sh from its local Git repo.
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

SEXTANT_DIR=$(dirname $(realpath $0))
INSTALL_CEPH_SCRIPT_DIR=$SEXTANT_DIR/install-ceph
CLUSTER_DESC=$(realpath $1)

source $SEXTANT_DIR/scripts/load_yaml.sh
# load yaml from "cluster-desc.yaml"
load_yaml $CLUSTER_DESC cluster_desc_

# Check sextant dir
if [[ "$SEXTANT_DIR" != "$GOPATH/src/github.com/k8sp/sextant" ]]; then
    echo "\$SEXTANT_DIR=$SEXTANT_DIR differs from $GOPATH/src/github.com/k8sp/sextant."
    echo "Please set GOPATH environment variable and use 'go get' to retrieve sextant."
    exit 1
fi

if [[ "$#" == 2 ]]; then
    BSROOT=$(realpath $2)
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
if [[ "$?" -ne 0 || "$KUBE_MASTER_HOSTNAME" == ""  ]]; then
    echo "The cluster-desc file should container kube-master node."
    exit 1
 fi

mkdir -p $BSROOT/config
cp $CLUSTER_DESC $BSROOT/config/cluster-desc.yml

# check_prerequisites checks for required software packages.
function check_prerequisites() {
    printf "Checking prerequisites ... "
    local err=0
    for tool in wget tar gpg docker tr go make; do
        command -v $tool >/dev/null 2>&1 || { echo "Install $tool before run this script"; err=1; }
    done
    if [[ $err -ne 0 ]]; then
        exit 1
    fi
    echo "Done"
}


check_cluster_desc_file() {
    printf "Cross-compiling validate-yaml ... "
    docker run --rm -it \
          --volume $GOPATH:/go \
          -e CGO_ENABLED=0 \
          -e GOOS=linux \
          -e GOARCH=amd64 \
          golang:wheezy \
          go get github.com/k8sp/sextant/golang/validate-yaml \
          || { echo "Build sextant failed..."; exit 1; }
    echo "Done"


    printf "Copying cloud-config template and cluster-desc.yml ... "
    mkdir -p $BSROOT/config > /dev/null 2>&1
    cp -r $SEXTANT_DIR/golang/template/templatefiles $BSROOT/config
    cp $CLUSTER_DESC $BSROOT/config
    echo "Done"

    printf "Checking cluster description file ..."
    docker run --rm -it \
        --volume $GOPATH:/go \
        --volume $BSROOT:/bsroot \
        golang:wheezy \
          /go/bin/validate-yaml \
          --cloud-config-dir /bsroot/config/templatefiles \
          -cluster-desc /bsroot/config/cluster-desc.yml \
          > /dev/null 2>&1 || { echo "Failed"; exit 1; }
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

generate_ceph_install_scripts() {
  printf "Generating Ceph installation scripts..."
  mkdir -p $BSROOT/html/static/ceph
  # update install-mon.sh and set OSD_JOURNAL_SIZE
  OSD_JOURNAL_SIZE=$cluster_desc_ceph_osd_journal_size
  # update ceph install scripts to use image configured in cluster-desc.yml
  CEPH_DAEMON_IMAGE=$(echo $cluster_desc_images_ceph | sed -e 's/[\/&]/\\&/g')
  printf "$CEPH_DAEMON_IMAGE..."
  sed "s/ceph\/daemon/$CEPH_DAEMON_IMAGE/g" $INSTALL_CEPH_SCRIPT_DIR/install-mon.sh | \
      sed "s/<JOURNAL_SIZE>/$OSD_JOURNAL_SIZE/g" \
      > $BSROOT/html/static/ceph/install-mon.sh || { echo "install-mon Failed"; exit 1; }

  sed "s/ceph\/daemon/$CEPH_DAEMON_IMAGE/g" $INSTALL_CEPH_SCRIPT_DIR/install-osd.sh \
      > $BSROOT/html/static/ceph/install-osd.sh || { echo "install-osd Failed"; exit 1; }
  echo "Done"

}


build_bootstrapper_image() {
    # cloud-config-server and addon compile moved to check_cluster_desc_file
    # Compile registry and build docker image here
    printf "Cross-compiling Docker registry ... "
    docker run --rm -it --name=registry_build \
          --volume $GOPATH:/go \
          -e CGO_ENABLED=0 \
          -e GOOS=linux \
          -e GOARCH=amd64 \
          golang:wheezy \
          sh -c "go get -u -d github.com/docker/distribution/cmd/registry && cd /go/src/github.com/docker/distribution && make PREFIX=/go clean /go/bin/registry >/dev/null" \
          || { echo "Complie Docker registry failed..."; exit 1; }

    printf "Cross-compiling cloud-config-server, addons ... "
    docker run --rm -it \
          --volume $GOPATH:/go \
          -e CGO_ENABLED=0 \
          -e GOOS=linux \
          -e GOARCH=amd64 \
          golang:wheezy \
          go get github.com/k8sp/sextant/golang/cloud-config-server github.com/k8sp/sextant/golang/addons \
          || { echo "Build sextant failed..."; exit 1; }
    echo "Done"


    rm -rf $SEXTANT_DIR/docker/{cloud-config-server,addons,registry}
    cp $GOPATH/bin/{cloud-config-server,addons,registry} $SEXTANT_DIR/docker
    echo "Done"

    printf "Building bootstrapper image ... "
    docker rm -f bootstrapper > /dev/null 2>&1 || echo "No such container: bootstrapper ,Pass..."
    docker rmi bootstrapper:latest > /dev/null 2>&1 || echo "No such images: bootstrapper ,Pass..."
    cd $SEXTANT_DIR/docker
    docker build -t bootstrapper .
    docker save bootstrapper:latest > $BSROOT/bootstrapper.tar || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Copying bash scripts ... "
    cp $SEXTANT_DIR/start_bootstrapper_container.sh $BSROOT/
    chmod +x $BSROOT/start_bootstrapper_container.sh
    cp $SEXTANT_DIR/scripts/load_yaml.sh $BSROOT/
    echo "Done"

    printf "Make directory ... "
    mkdir -p $BSROOT/dnsmasq
    echo "Done"
}


download_k8s_images() {
    # Fetch release binary tarball from github accroding to the versions
    # defined in "cluster-desc.yml"
    # hyperkube_version=`grep "hyperkube:" $CLUSTER_DESC | grep -o '".*hyperkube.*:.*"' | sed 's/".*://; s/"//'`
    # printf "Downloading kubelet ${hyperkube_version} ... "
    # wget --quiet -c -N -O $BSROOT/html/static/kubelet https://storage.googleapis.com/kubernetes-release/release/$hyperkube_version/bin/linux/amd64/kubelet
    printf "Downloading kubelet ... "
    wget --quiet -c -N -O $BSROOT/html/static/kubelet https://dl.dropboxusercontent.com/u/27178121/kubelet.v1.6.0/kubelet
    echo "Done"
    
    # setup-network-environment will fetch the default system IP infomation
    # when using cloud-config file to initiate a kubernetes cluster node
    printf "Downloading setup-network-environment file ... "
    wget --quiet -c -N -O $BSROOT/html/static/setup-network-environment-1.0.1 https://github.com/kelseyhightower/setup-network-environment/releases/download/1.0.1/setup-network-environment || { echo "Failed"; exit 1; }
    echo "Done"


    for DOCKER_IMAGE in $(set | grep '^cluster_desc_images_' | grep -o '".*"' | sed 's/"//g'); do
        # NOTE: if we updated remote image but didn't update its tag,
        # the following lines wouldn't pull because there is a local
        # image with the same tag.
        local DOCKER_DOMAIN_IMAGE_URL=$cluster_desc_dockerdomain:5000/${DOCKER_IMAGE}
        local DOCKER_TAR_FILE=$BSROOT/`echo $DOCKER_IMAGE.tar | sed "s/:/_/g" |awk -F'/' '{print $2}'`
        if [[ ! -f $DOCKER_TAR_FILE ]]; then
            if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep $DOCKER_DOMAIN_IMAGE_URL > /dev/null; then
                printf "Pulling image ${DOCKER_IMAGE} ... "
                docker pull $DOCKER_IMAGE > /dev/null 2>&1
                echo "Done"
            fi
            printf "Exporting $DOCKER_TAR_FILE ... "
            docker tag $DOCKER_IMAGE $DOCKER_DOMAIN_IMAGE_URL
            docker save $DOCKER_DOMAIN_IMAGE_URL > $DOCKER_TAR_FILE.progress
            mv $DOCKER_TAR_FILE.progress $DOCKER_TAR_FILE
            echo "Done"
        else 
            echo "Use existing $DOCKER_TAR_FILE"
        fi
    done
}


generate_tls_assets() {
    mkdir -p $BSROOT/tls
    cd $BSROOT/tls

    if [[ -f ca.pem ]] && [[ -f ca-key.pem ]] && [[ -f bootstrapper.key ]] \
        && [[ -f bootstrapper.csr ]] && [[ -f bootstrapper.crt ]]; then

        echo "Use exist CA TLS assets"

    else

        printf "Generating CA TLS assets ... "
        openssl genrsa -out ca-key.pem 2048 > /dev/null 2>&1
        openssl req -x509 -new -nodes -key ca-key.pem -days 3650 -out ca.pem -subj "/CN=kube-ca"  > /dev/null 2>&1
        echo "Done"

        printf "Generating bootstrapper TLS assets ... "
        openssl genrsa -out bootstrapper.key 2048 > /dev/null 2>&1
        openssl req -new -key bootstrapper.key -out bootstrapper.csr -subj "/CN=bootstrapper" > /dev/null 2>&1
        openssl x509 -req -in bootstrapper.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out bootstrapper.crt -days 3650 > /dev/null 2>&1
        echo "Done"

    fi
}

prepare_setup_kubectl() {
    printf "Downloading kubectl ... "
    wget --quiet -c -N -O $BSROOT/html/static/kubectl https://dl.dropboxusercontent.com/u/27178121/kubelet.v1.6.0/kubectl || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Preparing setup kubectl ... "
    sed -i -e "s/<KUBE_MASTER_HOSTNAME>/$KUBE_MASTER_HOSTNAME/g" $SEXTANT_DIR/setup-kubectl.bash
    sed -i -e "s/<BS_IP>/$BS_IP/g" $SEXTANT_DIR/setup-kubectl.bash
    cp $SEXTANT_DIR/setup-kubectl.bash $BSROOT/setup_kubectl.bash
    chmod +x $BSROOT/setup_kubectl.bash
    echo "Done"
}

generate_addons_config() {
    printf "Generating configuration files ..."
    mkdir -p $BSROOT/html/static/addons-config/

    docker run --rm -it \
            --volume $GOPATH:/go \
            --volume $CLUSTER_DESC:/cluster-desc.yaml \
            --volume $BSROOT:/bsroot \
            --volume $SEXTANT_DIR/scripts/common/addons.sh:/addons.sh \
            --volume $SEXTANT_DIR/golang/addons:/addons \
            golang:wheezy \
            /bin/bash /addons.sh

    for file in $(ls $SEXTANT_DIR/golang/addons/template/|grep \.yaml$)
    do
        cp $SEXTANT_DIR/golang/addons/template/$file $BSROOT/html/static/addons-config/$file;
    done

    echo "Done"
}

