#!/bin/bash

# assume that this shell script runs in the CAs folder
#mkdir ~/kube-ca

NODES_NUM=3
K8S_SERVICE_IP=10.3.0.1
MASTER_HOST=172.17.8.101

echo "Confirming variables ..."
echo "total nodes: ${NODES_NUM}"
echo "K8S service IP: ${K8S_SERVICE_IP}"
echo "master node IP: ${MASTER_HOST}"

##########################################################
# Create CA and Cluster Certificates with OpenSSL
# https://coreos.com/kubernetes/docs/latest/openssl.html
##########################################################

echo "Create a Cluster Root CA"

openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=kube-ca"

echo "Kubernetes API Server Keypair"
TEMPLATE=openssl.cnf

cat << EOF > $TEMPLATE
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = ${K8S_SERVICE_IP}
IP.2 = ${MASTER_HOST}
EOF

openssl genrsa -out apiserver-key.pem 2048
openssl req -new -key apiserver-key.pem -out apiserver.csr -subj "/CN=kube-apiserver" -config openssl.cnf
openssl x509 -req -in apiserver.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out apiserver.pem -days 365 -extensions v3_req -extfile openssl.cnf

echo "Kubernetes Worker Keypairs"
TEMPLATE=worker-openssl.cnf

cat << EOF > $TEMPLATE
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = \$ENV::WORKER_IP
EOF

for((i=1;i<$NODES_NUM;i++))
do
    echo "generating kube-worker-${i} certifactes"
    openssl genrsa -out kube-worker-${i}-worker-key.pem 2048
    WORKER_IP=172.17.8.10$((${i}+1)) openssl req -new -key kube-worker-${i}-worker-key.pem -out kube-worker-${i}-worker.csr -subj "/CN=kube-worker-${i}" -config worker-openssl.cnf
    WORKER_IP=172.17.8.10$((${i}+1)) openssl x509 -req -in kube-worker-${i}-worker.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out kube-worker-${i}-worker.pem -days 365 -extensions v3_req -extfile worker-openssl.cnf
done

echo "Generate the Cluster Administrator Keypair"
openssl genrsa -out admin-key.pem 2048
openssl req -new -key admin-key.pem -out admin.csr -subj "/CN=kube-admin"
openssl x509 -req -in admin.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out admin.pem -days 365
