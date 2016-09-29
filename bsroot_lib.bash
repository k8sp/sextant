check_prerequisites() {
    printf "Checking prerequisites ... "
    local err=0
    for tool in wget tar gpg docker; do
        command -v $tool >/dev/null 2>&1 || { echo "Install $tool before run this script"; err=1; }
    done
    if [[ $err -ne 0 ]]; then
        exit 1
    fi
    echo "Done"
}


download_pxe_images() {
    local BSROOT=$1

    mkdir -p $BSROOT/tftpboot

    printf "Downloading syslinux ... "
    wget --quiet -c -P $BSROOT/tftpboot https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz || { echo "Failed"; exit 1; }
    cd $BSROOT/tftpboot
    tar xzf syslinux-6.03.tar.gz || { echo "Failed"; exit 1; }
    cp syslinux-6.03/bios/core/pxelinux.0 $BSROOT/tftpboot || { echo "Failed"; exit 1; }
    cp syslinux-6.03/bios/com32/menu/vesamenu.c32 $BSROOT/tftpboot || { echo "Failed"; exit 1; }
    cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 $BSROOT/tftpboot || { echo "Failed"; exit 1; }
    rm -rf syslinux-6.03 || { echo "Failed"; exit 1; } # Clean the untarred.
    echo "Done"

    printf "Importing CoreOS signing key ... "
    wget --quiet -c -P $BSROOT/tftpboot https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc || { echo "Failed"; exit 1; }
    gpg --import --keyid-format LONG $BSROOT/tftpboot/CoreOS_Image_Signing_Key.asc > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Downloading CoreOS PXE vmlinuz image ... "
    wget --quiet -c -P $BSROOT/tftpboot https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz || { echo "Failed coreos_production_pxe.vmlinuz"; exit 1; }
    wget --quiet -c -P $BSROOT/tftpboot https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz.sig || { echo "Failed coreos_production_pxe.vmlinuz.sig"; exit 1; }
    cd $BSROOT/tftpboot
    gpg --verify coreos_production_pxe.vmlinuz.sig > /dev/null 2>&1 || { echo "Failed GPG verify"; exit 1; }
    echo "Done"

    printf "Downloading CoreOS PXE CPIO image ... "
    wget --quiet -c -P $BSROOT/tftpboot https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz || { echo "Failed"; exit 1; }
    wget --quiet -c -P $BSROOT/tftpboot https://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz.sig || { echo "Failed"; exit 1; }
    gpg --verify coreos_production_pxe_image.cpio.gz.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    echo "Done"
}


generate_pxe_config() {
    local BSROOT=$1
    local BS_IP=$2

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


generate_dnsmasq_config() {
    local BSROOT=$1

    printf "Generating dnsmasq.conf ... "
    mkdir -p $BSROOT/config
    # TODO(yi): Ad-hoc domain name k8s.baifendian.com here.  Try parsing it from cluster-desc.yml.
    # TODO(yi): Ad-hoc DHCP IP range. Try parsing it from cluster-desc.yml.
    cat > $BSROOT/config/dnsmasq.conf <<EOF
  interface=eth0
  bind-interfaces
  domain=k8s.baifendian.com
  user=root
  dhcp-range=192.168.8.102,192.168.8.200,255.255.255.0,12h
  log-dhcp

  dhcp-boot=pxelinux.0

  dhcp-option=3,192.168.8.101

  dhcp-option=6,192.168.8.101,8.8.8.8
  no-hosts
  expand-hosts
  no-resolv

  local=/k8s.baifendian.com/
  domain-needed

  dhcp-option=28,192.168.8.255

  #dhcp-option=42,0.0.0.0
  pxe-prompt="Press F8 for menu.", 5
  pxe-service=x86PC, "Install CoreOS from network server", pxelinux
  enable-tftp
  tftp-root=/bsroot/tftpboot
EOF
    echo "Done"
}


generate_registry_config() {
    local BSROOT=$1

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
    local BSROOT=$1
    local CLUSTER_DESC=$2
    local SEXTANT_DIR=$3
    local BS_IP=$4

    mkdir -p $BSROOT/html/static/cloud-config

    # Fetch release binary tarball from github accroding to the versions
    # defined in "cluster-desc.yml"
    local hyperkube_version=`grep "hyperkube_version:" $CLUSTER_DESC | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`
    printf "Downloading and kubelet and kubectl of release ${hyperkube_version} ... "
    wget --quiet -c -O $BSROOT/html/static/kubelet https://storage.googleapis.com/kubernetes-release/release/$hyperkube_version/bin/linux/amd64/kubelet
    wget --quiet -c -O $BSROOT/kubectl https://storage.googleapis.com/kubernetes-release/release/$hyperkube_version/bin/linux/amd64/kubectl
    chmod +x $BSROOT/html/static/kubelet
    chmod +x $BSROOT/kubectl
    echo "Done"

    # setup-network-environment will fetch the default system IP infomation
    # when using cloud-config file to initiate a kubernetes cluster node
    printf "Downloading setup-network-environment file ... "
    wget --quiet -c -O $BSROOT/html/static/setup-network-environment-1.0.1 https://github.com/kelseyhightower/setup-network-environment/releases/download/1.0.1/setup-network-environment || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Copying cloud-config template and cluster-desc.yml ... "
    local CLOUD_CONFIG_TEMPLATE=$SEXTANT_DIR/cloud-config-server/template/cloud-config.template
    cp $CLOUD_CONFIG_TEMPLATE $BSROOT/config/ || { echo "Failed"; exit 1; }
    cp $CLUSTER_DESC $BSROOT/config/cluster-desc.yml || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Copying ingress template and skydns template ... "
    local INGRESS_TEMPLATE=$SEXTANT_DIR/addons/template/ingress.template
    cp $INGRESS_TEMPLATE $BSROOT/config/ || { echo "Failed"; exit 1; }
    local SKYDNS_TEMPLATE=$SEXTANT_DIR/addons/template/skydns.template
    cp $SKYDNS_TEMPLATE $BSROOT/config/ || { echo "Failed"; exit 1; }
    echo "Done"

    printf "Generating install.sh ... "
    cat > $BSROOT/html/static/cloud-config/install.sh <<EOF
#!/bin/bash
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
    local VERSION=$(curl -s https://stable.release.core-os.net/amd64-usr/current/version.txt | grep 'COREOS_VERSION=' | cut -f 2 -d '=')
    if [[ $VERSION == "" ]]; then
	echo "Failed"; exit 1;
    fi
    echo "Done"

    printf "Updating CoreOS images ... "
    if [[ ! -d $BSROOT/html/static/$VERSION ]]; then
        mkdir -p $BSROOT/html/static/$VERSION
    fi

    wget --quiet -c -P $BSROOT/html/static/$VERSION https://stable.release.core-os.net/amd64-usr/current/version.txt
    wget --quiet -c -P $BSROOT/html/static/$VERSION https://stable.release.core-os.net/amd64-usr/current/coreos_production_image.bin.bz2 || { echo "Failed"; exit 1; }
    wget --quiet -c -P $BSROOT/html/static/$VERSION https://stable.release.core-os.net/amd64-usr/current/coreos_production_image.bin.bz2.sig || { echo "Failed"; exit 1; }
    (
	cd $BSROOT/html/static/$VERSION
	gpg --verify coreos_production_image.bin.bz2.sig > /dev/null 2>&1 || { echo "Failed"; exit 1; }
    )
    ln -sf $BSROOT/html/static/$VERSION $BSROOT/html/static/current || { echo "Failed"; exit 1; }
    echo "Done"
}


download_k8s_images() {
    local BSROOT=$1
    local CLUSTER_DESC=$2
    local SEXTANT_DIR=$3

    local hyperkube_version=`grep "hyperkube_version:" $CLUSTER_DESC | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`
    local pause_version=`grep "pause_version:" $CLUSTER_DESC | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`
    local flannel_version=`grep "flannel_version:" $CLUSTER_DESC | awk '{print $2}' | sed 's/ //g' | sed -e 's/^"//' -e 's/"$//'`

    local DOCKER_IMAGES=("typhoon1986/hyperkube-amd64:${hyperkube_version}" \
			     "typhoon1986/pause:${pause_version}" \
			     "typhoon1986/flannel:${flannel_version}" \
			     "yancey1989/nginx-ingress-controller:0.8.3" \
			     "yancey1989/kube2sky:1.14" \
			     "typhoon1986/exechealthz:1.0" \
			     "yancey1989/kube-addon-manager-amd64:v5.1" \
			     "typhoon1986/skydns:latest");
    (
	cd $BSROOT
	local len=${#DOCKER_IMAGES[@]}
	for ((i=0;i<len;i++)); do
	    local DOCKER_IMAGE=${DOCKER_IMAGES[i]}
	    local DOCKER_TAR_FILE=`echo $DOCKER_IMAGE.tar | sed "s/:/_/g" |awk -F'/' '{print $2}'`
	    if [ ! -f $DOCKER_TAR_FILE ]; then
		printf "Downloading image ${DOCKER_IMAGE} ..."
		docker pull $DOCKER_IMAGE > /dev/null 2>&1 || { echo "Failed"; exit 1; }
		docker save $DOCKER_IMAGE > $DOCKER_TAR_FILE || { echo "Failed"; exit 1; }
		echo "Done"
	    fi
	done
    )
}

build_bootstrapper_image() {
    local BSROOT=$1
    local SEXTANT_DIR=$2

    printf "Building bootstrapper image ... "
    (
	cd $SEXTANT_DIR/docker
	bash $SEXTANT_DIR/docker/build.bash > /dev/null 2>&1 || { echo "Failed"; exit 1; }
	docker save bootstrapper:latest > $BSROOT/bootstrapper.tar || { echo "Failed"; exit 1; }
	echo "Done"
	# NOTE: we need to run docker load on the bootstrapper server
	# to load these saved images.
    )

    cp $SEXTANT_DIR/start_bootstrapper_container.sh \
       $BSROOT/start_bootstrapper_container.sh 2>&1 || { echo "Failed"; exit 1; }
    chmod +x $BSROOT/start_bootstrapper_container.sh
}

generate_tls_assets() {
    local BSROOT=$1

    mkdir -p $BSROOT/tls
    (
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
    )
}
