#!/bin/bash

# More about TLS assets: https://github.com/k8sp/tls/blob/master/openssl.md
openssl genrsa -out ca.key 2048
openssl req -nodes -new -key ca.key -subj "/CN=company.com" -out ca.csr
openssl x509 -req -sha256 -days 365 -in ca.csr -signkey ca.key -out ca.crt

openssl genrsa -out bootstrapper.key 2048
openssl req -nodes -new -key bootstrapper.key -subj "/CN=bootstrapper" -out bootstrapper.csr
openssl x509 -req -sha256 -days 365 -in bootstrapper.csr -signkey ca.key -out bootstrapper.crt
