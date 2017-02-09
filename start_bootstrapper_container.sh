#!/bin/bash

# start_bootstrapper_container.sh load docker image from bsroot and
# then push them to registry
if [[ "$#" -gt 1 ]]; then
    echo "Usage: start_bootstrapper_container.sh [bsroot-path]"
    exit 1
elif [[ "$#" -ne 1 ]]; then
    BSROOT=$(cd `dirname $0`; pwd)
else
    BSROOT=$1
fi

if [[ ! -d $BSROOT ]]; then
    echo "$BSROOT is not a directory"
    exit 2
fi

if [[ $BSROOT != /* ]]; then
  echo "bsroot path not start with / !"
  exit 1
fi

if [[ -e "$BSROOT/html/static/CentOS7/CentOS-7-x86_64-Everything-1611.iso" ]]; then
    if [[ ! -d "$BSROOT/html/static/CentOS7/dvd_content" ]]; then
        mkdir -p $BSROOT/html/static/CentOS7/dvd_content
    fi
    if [[ ! -f "$BSROOT/html/static/CentOS7/dvd_content/.treeinfo" ]]; then
        sudo mount -t iso9660 -o loop $BSROOT/html/static/CentOS7/CentOS-7-x86_64-Everything-1611.iso $BSROOT/html/static/CentOS7/dvd_content || { echo "Mount iso failed"; exit 1; }
    fi
fi

# Config Registry tls
mkdir -p /etc/docker/certs.d/bootstrapper:5000
rm -rf /etc/docker/certs.d/bootstrapper:5000/*
cp $BSROOT/tls/ca.pem /etc/docker/certs.d/bootstrapper:5000/ca.crt

if ! grep -q "127.0.0.1 bootstrapper" /etc/hosts
  then echo "127.0.0.1 bootstrapper" >> /etc/hosts
fi

ntp_set=$(grep '^set_ntp' $BSROOT/config/cluster-desc.yml|cut -d : -f2)
if [[ $ntp_set == " y" ]]; then
docker load < $BSROOT/docker-ntp-server.tar > /dev/null 2>&1 || { echo "Docker can not load ntpserver.tar!"; exit 1; }
docker rm -f ntpserver > /dev/null 2>&1
docker run -d \
       --name ntpserver \
       --net=host \
       --privileged \
       redaphid/docker-ntp-server || { echo "Failed"; exit -1; }
fi

# Configure early-docker.service
os_release=$(grep -w  NAME /etc/os-release |cut -d "=" -f2)
if [[ $os_release != "CoreOS" ]];then
 mkdir -p /usr/lib/centos
 cat > /usr/lib/centos/dockerd <<EOF
#!/bin/bash
# Wrapper for launching docker daemons with an appropriate backend.

set -e

parse_docker_args() {
    local flag
    while [[ $# -gt 0 ]]; do
        flag="$1"
        shift

        # treat --flag=foo and --flag foo identically
        if [[ "${flag}" == *=* ]]; then
            set -- "${flag#*=}" "$@"
            flag="${flag%=*}"
        fi

        case "${flag}" in
            -g|--graph)
                ARG_ROOT="$1"
                shift
                ;;
            -s|--storage-driver)
                ARG_DRIVER="$1"
                shift
                ;;
            --selinux-enabled)
                ARG_SELINUX="$1"
                shift
                ;;
            *)
                # ignore everything else
                ;;
        esac
    done
}

select_docker_driver() {
    local fstype

    # mimic docker's behavior to ensure we stat the right filesystem.
    if [[ -L "${ARG_ROOT}" ]]; then
        ARG_ROOT="$(readlink -f "${ARG_ROOT}")"
    fi

    mkdir --parents --mode=0700 "${ARG_ROOT}"
    fstype=$(findmnt --noheadings --output FSTYPE --target "${ARG_ROOT}")

    case "${fstype}" in
        btrfs)
            export DOCKER_DRIVER=btrfs
            ;;
        ext4|tmpfs|xfs) # As of 4.1
            export DOCKER_DRIVER=overlay
            ;;
        *)
            # Fall back to whatever docker's default behavior is.
            ;;
    esac
}

# Enable selinux except when known to be unsupported (btrfs).
maybe_enable_selinux() {
    case "${DOCKER_DRIVER}" in
        btrfs)
            USE_SELINUX=""
            ;;
        *)
            # Enable for everything else.
            #USE_SELINUX="--selinux-enabled"
            ;;
    esac
}

ARG_ROOT="/var/lib/docker"
ARG_DRIVER=""
parse_docker_args "$@"

# Do not override the driver if it is already explicitly configured.
if [[ -z "${ARG_DRIVER}" && -z "${DOCKER_DRIVER}" ]]; then
    select_docker_driver
fi

USE_SELINUX=""
# Do not override selinux if it is already explicitly configured.
if [[ -z "${ARG_SELINUX}" ]]; then
        maybe_enable_selinux
fi

exec docker "$@" ${USE_SELINUX}
EOF
  chmod +x /usr/lib/centos/dockerd

  cat >/usr/lib/systemd/system/early-docker.target<<EOF
[Unit]
Description=Run Docker containers before main Docker starts up
EOF

  cat >/usr/lib/systemd/system/early-docker.socket<<EOF
[Unit]
Description=Early Docker Socket for the API
PartOf=early-docker.service

[Socket]
ListenStream=/var/run/early-docker.sock

[Install]
WantedBy=sockets.target
EOF

  cat > /usr/lib/systemd/system/early-docker.service <<EOF
# /usr/lib64/systemd/system/early-docker.service
[Unit]
Description=Early Docker Application Container Engine
Documentation=http://docs.docker.com
After=early-docker.socket
Requires=early-docker.socket

[Service]
Environment="DOCKER_CGROUPS=--exec-opt native.cgroupdriver=systemd"
Environment=TMPDIR=/var/tmp
MountFlags=slave
LimitNOFILE=1048576
LimitNPROC=1048576
ExecStart=/usr/lib/centos/dockerd daemon --host=fd:// --bridge=none --iptables=false --ip-masq=false --graph=/var/lib/early-docker --pidfile=/var/run/early-docker.pid $DOCKER_OPTS $DOCKER_CGROUPS

[Install]
WantedBy=early-docker.target
EOF
# Reload  systemd manager configuration
systemctl daemon-reload
fi

systemctl restart early-docker
docker -H unix:///var/run/early-docker.sock rm -f bootstrapper > /dev/null 2>&1
docker -H unix:///var/run/early-docker.sock rmi bootstrapper:latest > /dev/null 2>&1
docker -H unix:///var/run/early-docker.sock \
      load < $BSROOT/bootstrapper.tar > /dev/null 2>&1 || { echo "Docker can not load bootstrapper.tar!"; exit 1; }
docker -H unix:///var/run/early-docker.sock \
       run -d \
       --name bootstrapper \
       --net=host \
       --privileged \
       -v /var/run/docker.sock:/var/run/docker.sock \
       -v $BSROOT:/bsroot \
       bootstrapper || { echo "Failed"; exit -1; }

# Sleep 3 seconds, waitting for registry started.
sleep 3

source $BSROOT/load_yaml.sh
load_yaml $BSROOT/config/cluster-desc.yml cluster_desc_

for DOCKER_IMAGE in $(set | grep '^cluster_desc_images_' | grep -o '".*"' | sed 's/"//g'); do
  DOCKER_TAR_FILE=$BSROOT/$(echo ${DOCKER_IMAGE}.tar | sed "s/:/_/g" |awk -F'/' '{print $2}')
  LOCAL_DOCKER_URL=$cluster_desc_dockerdomain:5000/${DOCKER_IMAGE}
  docker load < $DOCKER_TAR_FILE
  docker tag $DOCKER_IMAGE $LOCAL_DOCKER_URL
  docker push $LOCAL_DOCKER_URL
done
