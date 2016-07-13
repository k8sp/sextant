#! /bin/bash

MASTER_HOST=10.10.10.211
CA_CERT=ca.pem
ADMIN_KEY=admin-key.pem
ADMIN_CERT=admin.pem

echo $CA_CERT
echo $ADMIN_KEY
echo $ADMIN_CERT


./kubectl config set-cluster default-cluster --server=https://${MASTER_HOST} --certificate-authority=${CA_CERT}
./kubectl config set-credentials default-admin --certificate-authority=${CA_CERT} --client-key=${ADMIN_KEY} --client-certificate=${ADMIN_CERT}
./kubectl config set-context default-system --cluster=default-cluster --user=default-admin
./kubectl config use-context default-system
