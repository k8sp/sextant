#!/usr/bin/env bash

set -ex

# generate apiserver
openssl genrsa -out apiserver-key.pem 2048
openssl req -new -key apiserver-key.pem -out apiserver.csr -subj '/CN=kube-apiserver' -config openssl-srv.conf
openssl x509 -req -in apiserver.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out apiserver.pem -days 1000 -extensions v3_req -extfile openssl-srv.conf

# generate woker
openssl genrsa -out worker-key.pem 2048
openssl req -new -key worker-key.pem -out worker.csr -subj '/CN=woker' -config openssl-cli.conf
openssl x509 -req -in worker.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out worker.pem -days 1000 -extensions v3_req -extfile openssl-cli.conf


