#!/bin/bash

WORKER_FQDN=kube-worker-1
ADVERTISE_IP=172.17.8.102
ETCD_ENDPOINTS=http://172.17.8.101:2379,http://172.17.8.102:2379,http://172.17.8.103:2379
MASTER_HOST=172.17.8.101
DNS_SERVICE_IP=10.3.0.10
K8S_VER=v1.2.4_coreos.1

echo "Confirming variables ..."
echo "worker FQDN: ${WORKER_FQDN}"
echo "this machine IP: ${ADVERTISE_IP}"
echo "etcd clusers endpoints: ${ETCD_ENDPOINTS}"
echo "master node IP: ${MASTER_HOST}"
echo "DNS service IP: ${DNS_SERVICE_IP}"
echo "K8S version: ${K8S_VER}"

echo "Configuring Service Components ..."
# TLS Assets
# Assume that now in certs directory with all the certs needed
TLS_PATH=/etc/kubernetes/ssl
sudo mkdir -p ${TLS_PATH}
sudo cp *.pem ${TLS_PATH}
sudo chmod 600 /etc/kubernetes/ssl/*-key.pem
sudo chown root:root /etc/kubernetes/ssl/*-key.pem

#cd /etc/kubernetes/ssl/
sudo ln -s ${TLS_PATH}/${WORKER_FQDN}-worker.pem ${TLS_PATH}/worker.pem
sudo ln -s ${TLS_PATH}/${WORKER_FQDN}-worker-key.pem ${TLS_PATH}/worker-key.pem

# Networking Configuration
sudo mkdir -p /etc/flannel
TEMPLATE=/etc/flannel/options.env
cat << EOF > $TEMPLATE
FLANNELD_IFACE=${ADVERTISE_IP}
FLANNELD_ETCD_ENDPOINTS=${ETCD_ENDPOINTS}
EOF

TEMPLATE=/etc/systemd/system/flanneld.service.d/40-ExecStartPre-symlink.conf
cat << EOF > $TEMPLATE
[Service]
ExecStartPre=/usr/bin/ln -sf /etc/flannel/options.env /run/flannel/options.env
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d
# Docker Configuration
TEMPLATE=/etc/systemd/system/docker.service.d/40-flannel.conf
cat << EOF > $TEMPLATE
[Unit]
Requires=flanneld.service
After=flanneld.service
EOF

# Create the kubelet Unit
TEMPLATE=/etc/systemd/system/kubelet.service
cat << EOF > $TEMPLATE
[Service]
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests

Environment=KUBELET_VERSION=${K8S_VER}
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --api-servers=https://${MASTER_HOST} \
  --network-plugin-dir=/etc/kubernetes/cni/net.d \
  --network-plugin=${NETWORK_PLUGIN} \
  --register-node=true \
  --allow-privileged=true \
  --config=/etc/kubernetes/manifests \
  --hostname-override=${ADVERTISE_IP} \
  --cluster-dns=${DNS_SERVICE_IP} \
  --cluster-domain=cluster.local \
  --kubeconfig=/etc/kubernetes/worker-kubeconfig.yaml \
  --tls-cert-file=/etc/kubernetes/ssl/worker.pem \
  --tls-private-key-file=/etc/kubernetes/ssl/worker-key.pem
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /etc/kubernetes/manifests
# Set Up the kube-proxy Pod
TEMPLATE=/etc/kubernetes/manifests/kube-proxy.yaml
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
    image: quay.io/coreos/hyperkube:${K8S_VER}
    command:
    - /hyperkube
    - proxy
    - --master=https://${MASTER_HOST}
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

# Set Up kubeconfig
TEMPLATE=/etc/kubernetes/worker-kubeconfig.yaml
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

echo "Starting Services ..."
sudo systemctl daemon-reload
sleep 5
echo " ... "
sudo systemctl start flanneld
sleep 5
echo " ... "
sudo systemctl start kubelet
sleep 10

echo "Making services start on boot ..."
sudo systemctl enable flanneld
sudo systemctl enable kubelet

echo "pull images from docker.io instead, and rename them"
echo "pulling pause:2.0 ..."
docker pull typhoon1986/pause:2.0
docker tag typhoon1986/pause:2.0 gcr.io/google_containers/pause:2.0
echo "pulling hyperkube:${K8S_VER}"
docker pull typhoon1986/hyperkube-amd64:v1.2.0
docker tag typhoon1986/hyperkube-amd64:v1.2.0 quay.io/coreos/hyperkube:v1.2.4_coreos.1
