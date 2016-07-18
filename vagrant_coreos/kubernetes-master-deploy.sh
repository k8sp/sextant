#!/bin/bash

# assume that this shell script runs in the CAs folder
#mkdir ~/kube-ca

MASTER_HOST=172.17.8.101
ADVERTISE_IP=172.17.8.101
ETCD_ENDPOINTS=http://172.17.8.101:2379,http://172.17.8.102:2379,http://172.17.8.103:2379
SERVICE_IP_RANGE=10.3.0.0/24
DNS_SERVICE_IP=10.3.0.10
K8S_VER=v1.2.4_coreos.1
POD_NETWORK=10.2.0.0/16
ETCD_SERVER=http://172.17.8.101:2379

echo "Confirming variables ..."
echo "this machine IP: ${ADVERTISE_IP}"
echo "master node IP: ${MASTER_HOST}"
echo "etcd clusers endpoints: ${ETCD_ENDPOINTS}"
echo "DNS service IP: ${DNS_SERVICE_IP}"
echo "K8S version: ${K8S_VER}"
echo "service IP range: ${SERVICE_IP_RANGE}"
echo "pod network: ${POD_NETWORK}"


###################################################################
# Deploy Kubernetes Master Node(s)
# https://coreos.com/kubernetes/docs/latest/deploy-master.html
###################################################################

echo "Configure Service Components ..."
# TLS Assets
sudo mkdir -p /etc/kubernetes/ssl
sudo cp ca.pem /etc/kubernetes/ssl/ca.pem
sudo cp apiserver.pem /etc/kubernetes/ssl/apiserver.pem
sudo cp apiserver-key.pem /etc/kubernetes/ssl/apiserver-key.pem

sudo chmod 600 /etc/kubernetes/ssl/*-key.pem
sudo chown root:root /etc/kubernetes/ssl/*-key.pem

# Network Configuration without Calico
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
  --api-servers=http://127.0.0.1:8080 \
  --network-plugin-dir=/etc/kubernetes/cni/net.d \
  --network-plugin=${NETWORK_PLUGIN} \
  --register-schedulable=false \
  --allow-privileged=true \
  --config=/etc/kubernetes/manifests \
  --hostname-override=${ADVERTISE_IP} \
  --cluster-dns=${DNS_SERVICE_IP} \
  --cluster-domain=cluster.local
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /etc/kubernetes/manifests

# Set Up the kube-apiserver Pod
TEMPLATE=/etc/kubernetes/manifests/kube-apiserver.yaml
cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-apiserver
    image: quay.io/coreos/hyperkube:v1.2.4_coreos.1
    command:
    - /hyperkube
    - apiserver
    - --bind-address=0.0.0.0
    - --etcd-servers=${ETCD_ENDPOINTS}
    - --allow-privileged=true
    - --service-cluster-ip-range=${SERVICE_IP_RANGE}
    - --secure-port=443
    - --advertise-address=${ADVERTISE_IP}
    - --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota
    - --tls-cert-file=/etc/kubernetes/ssl/apiserver.pem
    - --tls-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --client-ca-file=/etc/kubernetes/ssl/ca.pem
    - --service-account-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --runtime-config=extensions/v1beta1=true,extensions/v1beta1/thirdpartyresources=true
    ports:
    - containerPort: 443
      hostPort: 443
      name: https
    - containerPort: 8080
      hostPort: 8080
      name: local
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF

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
    image: quay.io/coreos/hyperkube:v1.2.4_coreos.1
    command:
    - /hyperkube
    - proxy
    - --master=http://127.0.0.1:8080
    - --proxy-mode=iptables
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF

# Set Up the kube-controller-manager Pod
TEMPLATE=/etc/kubernetes/manifests/kube-controller-manager.yaml
cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-controller-manager
    image: quay.io/coreos/hyperkube:v1.2.4_coreos.1
    command:
    - /hyperkube
    - controller-manager
    - --master=http://127.0.0.1:8080
    - --leader-elect=true
    - --service-account-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --root-ca-file=/etc/kubernetes/ssl/ca.pem
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10252
      initialDelaySeconds: 15
      timeoutSeconds: 1
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF

# Set Up the kube-scheduler Pod
TEMPLATE=/etc/kubernetes/manifests/kube-scheduler.yaml
cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-scheduler
    image: quay.io/coreos/hyperkube:v1.2.4_coreos.1
    command:
    - /hyperkube
    - scheduler
    - --master=http://127.0.0.1:8080
    - --leader-elect=true
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10251
      initialDelaySeconds: 15
      timeoutSeconds: 1
EOF

echo "Start Services ..."
sudo systemctl daemon-reload
echo "..."
curl -X PUT -d "value={\"Network\":\"${POD_NETWORK}\",\"Backend\":{\"Type\":\"vxlan\"}}" "${ETCD_SERVER}/v2/keys/coreos.com/network/config"

sudo systemctl start kubelet
sudo systemctl enable kubelet
echo "..."

echo "pull images from docker.io instead, and rename them"
echo "pulling pause:2.0 ..."
docker pull typhoon1986/pause:2.0
docker tag typhoon1986/pause:2.0 gcr.io/google_containers/pause:2.0
echo "pulling hyperkube:${K8S_VER}"
docker pull typhoon1986/hyperkube-amd64:v1.2.0
docker tag typhoon1986/hyperkube-amd64:v1.2.0 quay.io/coreos/hyperkube:v1.2.4_coreos.1