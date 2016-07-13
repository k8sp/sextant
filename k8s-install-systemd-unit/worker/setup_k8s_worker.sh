#!/bin/bash

# 本脚本实现了在bare-metal上对kubernetes的worker节点的自动安装。
# 使用本脚本前要确认coreos上的etcd2服务和flanneld服务已经正常运行。如果这两个服务不能正常运行，请参见：
# https://github.com/k8sp/bare-metal-coreos/pull/5/files/6f0c6ac9d371385be42f1bca990a69fe75309ad9?short_path=9189e72#diff-9189e729dd6dcd55d55a209facc4a6db

# 本脚本编写过程中主要参考了coreos官网安装k8s的step by step 教程，地址如下：

# 0. https://coreos.com/kubernetes/docs/latest/openssl.html
# 1. https://coreos.com/kubernetes/docs/latest/getting-started.html
# 2. https://coreos.com/kubernetes/docs/latest/deploy-master.html
# 3. https://coreos.com/kubernetes/docs/latest/deploy-workers.html
# 4. https://coreos.com/kubernetes/docs/latest/configure-kubectl.html
# 5. https://coreos.com/kubernetes/docs/latest/deploy-addons.html

# 本脚本代码主要基于：https://github.com/coreos/coreos-kubernetes 中的
# https://github.com/coreos/coreos-kubernetes/blob/master/multi-node/generic/controller-install.sh

# 本脚本阅读方法是：先看末尾，因为末尾包含了主流程，每一步都有注释解释。

# 本脚本以及相关配置文件预设：MasterNodeIP=10.10.10.191, WorkerNodeIP=10.10.10.192

# environment is a file which contains the IP of the worker
cp environment /etc/ -f

export CONTROLLER_ENDPOINT="https://$(awk -F= '/KUBERNETES_MASTER_IPV4/ {print $2}' /etc/environment)"
export COREOS_PUBLIC_IPV4=$(LC_ALL=C ifconfig | grep 'inet ' | egrep -v '(127\.0\.0\.1)|(10\.1\..*)'|awk '{print $2}')
export HYPERKUBE_IMAGE_REPO=quay.io/coreos/hyperkube
export ENV_FILE=/run/coreos-kubernetes/options.env
export ETCD_ENDPOINTS="http://${COREOS_PUBLIC_IPV4}:2379"
export K8S_VER=v1.2.4_coreos.cni.1
export HYPERKUBE_IMAGE_REPO=quay.io/coreos/hyperkube
export POD_NETWORK=10.2.0.0/16
export SERVICE_IP_RANGE=10.3.0.0/24
export K8S_SERVICE_IP=10.3.0.1
export DNS_SERVICE_IP=10.3.0.10
export USE_CALICO=false
export SSL_PATH=/etc/kubernetes/ssl

echo "CONTROLLER_ENDPOINT=$CONTROLLER_ENDPOINT"
echo "ETCD_ENDPOINTS=$ETCD_ENDPOINTS"


function check_kubelet_install {
  systemctl status kubelet.service | grep 'not-found'
  if [[ ! $? -eq 0 ]]; then
    echo "kubelet service is installed."
    exit 0
  fi
}

function init_tls {

  [ -d $SSL_PATH ] || {
    echo "make ssl path"
    mkdir -p $SSL_PATH
  }

  CURRENT_WORKER_IP=$COREOS_PUBLIC_IPV4
  WORKER_FQDN=$(hostname)
  echo "CURRENT_WORKER_IP=$CURRENT_WORKER_IP"
  echo "WORKER_FQDN=$WORKER_FQDN"
  openssl genrsa -out ${WORKER_FQDN}-worker-key.pem 2048
	WORKER_IP=${CURRENT_WORKER_IP} openssl req -new -key ${WORKER_FQDN}-worker-key.pem -out ${WORKER_FQDN}-worker.csr -subj "/CN=${WORKER_FQDN}" -config worker-openssl.cnf
	WORKER_IP=${CURRENT_WORKER_IP} openssl x509 -req -in ${WORKER_FQDN}-worker.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out ${WORKER_FQDN}-worker.pem -days 365 -extensions v3_req -extfile worker-openssl.cnf

	rm -f /etc/kubernetes/ssl/*
	\cp -fuv ca.pem *worker*.pem /etc/kubernetes/ssl

	chmod 600 /etc/kubernetes/ssl/*-key.pem
	chown root:root /etc/kubernetes/ssl/*-key.pem

	cd /etc/kubernetes/ssl/
	ln -sf ${WORKER_FQDN}-worker.pem worker.pem
	ln -sf ${WORKER_FQDN}-worker-key.pem worker-key.pem
}


function init_config {
    local REQUIRED=( 'ADVERTISE_IP' 'ETCD_ENDPOINTS' 'CONTROLLER_ENDPOINT' 'DNS_SERVICE_IP' 'K8S_VER' 'HYPERKUBE_IMAGE_REPO' 'USE_CALICO' )

    if [ -z $ADVERTISE_IP ]; then
        export ADVERTISE_IP=$COREOS_PUBLIC_IPV4
    fi

    if [ -f $ENV_FILE ]; then
        export $(cat $ENV_FILE | xargs)
    fi

    for REQ in "${REQUIRED[@]}"; do
        if [ -z "$(eval echo \$$REQ)" ]; then
            echo "Missing required config value: ${REQ}"
            exit 1
        fi
    done

    if [ $USE_CALICO = "true" ]; then
        export K8S_NETWORK_PLUGIN="cni"
    else
        export K8S_NETWORK_PLUGIN=""
    fi
}

function init_templates {
    local TEMPLATE=/etc/systemd/system/kubelet.service
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Service]
Environment=KUBELET_VERSION=${K8S_VER}
Environment=KUBELET_ACI=${HYPERKUBE_IMAGE_REPO}
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --api-servers=${CONTROLLER_ENDPOINT} \
  --network-plugin-dir=/etc/kubernetes/cni/net.d \
  --network-plugin=${K8S_NETWORK_PLUGIN} \
  --register-node=true \
  --allow-privileged=true \
  --config=/etc/kubernetes/manifests \
  --hostname-override=${ADVERTISE_IP} \
  --cluster_dns=${DNS_SERVICE_IP} \
  --cluster_domain=cluster.local \
  --kubeconfig=/etc/kubernetes/worker-kubeconfig.yaml \
  --tls-cert-file=/etc/kubernetes/ssl/worker.pem \
  --tls-private-key-file=/etc/kubernetes/ssl/worker-key.pem
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    }

    local TEMPLATE=/etc/systemd/system/calico-node.service
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Unit]
Description=Calico per-host agent
Requires=network-online.target
After=network-online.target

[Service]
Slice=machine.slice
Environment=CALICO_DISABLE_FILE_LOGGING=true
Environment=HOSTNAME=${ADVERTISE_IP}
Environment=IP=${ADVERTISE_IP}
Environment=FELIX_FELIXHOSTNAME=${ADVERTISE_IP}
Environment=CALICO_NETWORKING=false
Environment=NO_DEFAULT_POOLS=true
Environment=ETCD_ENDPOINTS=${ETCD_ENDPOINTS}
ExecStart=/usr/bin/rkt run --inherit-env --stage1-from-dir=stage1-fly.aci \
--volume=modules,kind=host,source=/lib/modules,readOnly=false \
--mount=volume=modules,target=/lib/modules \
--trust-keys-from-https quay.io/calico/node:v0.19.0
KillMode=mixed
Restart=always
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    }

    local TEMPLATE=/etc/kubernetes/worker-kubeconfig.yaml
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    certificate-authority: /etc/kubernetes/ssl/ca.pem
users:
- name: kubelet
  user:
    client-certificate: /etc/kubernetes/ssl/worker.pem
    client-key: /etc/kubernetes/ssl/worker-key.pem
contexts:
- context:
    cluster: local
    user: kubelet
  name: kubelet-context
current-context: kubelet-context
EOF
    }

    local TEMPLATE=/etc/kubernetes/manifests/kube-proxy.yaml
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-proxy
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-proxy
    image: ${HYPERKUBE_IMAGE_REPO}:$K8S_VER
    command:
    - /hyperkube
    - proxy
    - --master=${CONTROLLER_ENDPOINT}
    - --kubeconfig=/etc/kubernetes/worker-kubeconfig.yaml
    - --proxy-mode=iptables
    securityContext:
      privileged: true
    volumeMounts:
      - mountPath: /etc/ssl/certs
        name: "ssl-certs"
      - mountPath: /etc/kubernetes/worker-kubeconfig.yaml
        name: "kubeconfig"
        readOnly: true
      - mountPath: /etc/kubernetes/ssl
        name: "etc-kube-ssl"
        readOnly: true
  volumes:
    - name: "ssl-certs"
      hostPath:
        path: "/usr/share/ca-certificates"
    - name: "kubeconfig"
      hostPath:
        path: "/etc/kubernetes/worker-kubeconfig.yaml"
    - name: "etc-kube-ssl"
      hostPath:
        path: "/etc/kubernetes/ssl"
EOF
    }

    local TEMPLATE=/etc/flannel/options.env
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
FLANNELD_IFACE=$ADVERTISE_IP
FLANNELD_ETCD_ENDPOINTS=$ETCD_ENDPOINTS
EOF
    }

    local TEMPLATE=/etc/systemd/system/flanneld.service.d/40-ExecStartPre-symlink.conf.conf
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Service]
ExecStartPre=/usr/bin/ln -sf /etc/flannel/options.env /run/flannel/options.env
EOF
    }

    local TEMPLATE=/etc/systemd/system/docker.service.d/40-flannel.conf
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Unit]
Requires=flanneld.service
After=flanneld.service
EOF
    }

     local TEMPLATE=/etc/kubernetes/cni/net.d/10-calico.conf
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
    "name": "calico",
    "type": "flannel",
    "delegate": {
        "type": "calico",
        "etcd_endpoints": "$ETCD_ENDPOINTS",
        "log_level": "none",
        "log_level_stderr": "info",
        "hostname": "${ADVERTISE_IP}",
        "policy": {
            "type": "k8s",
            "k8s_api_root": "${CONTROLLER_ENDPOINT}:443/api/v1/",
            "k8s_client_key": "/etc/kubernetes/ssl/worker-key.pem",
            "k8s_client_certificate": "/etc/kubernetes/ssl/worker.pem"
        }
    }
}
EOF
    }

}

# Check kubelet installation
check_kubelet_install

# generate tls assets and put them in /etc/kubernetes/ssl
init_tls

# init and check the configure value
init_config

# generate kubelet service configure files and save them into /etc/kubernetes/manifests
init_templates

# start kubelet service
systemctl daemon-reload
systemctl enable kubelet; systemctl restart kubelet

