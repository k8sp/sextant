#!/bin/bash

# References:
#  1. https://github.com/k8sp/tls/blob/master/bidirectional/create_tls_asserts.bash

# 1. 创建我们自己CA的私钥：

openssl genrsa -out ca.key 2048

# 创建我们自己CA的CSR，并且用自己的私钥自签署之，得到CA的身份证：

openssl req -x509 -new -nodes -key ca.key -days 10000 -out ca.crt -subj "/CN=we-as-ca"

# 2. 创建server的私钥，CSR，并且用CA的私钥自签署server的身份证：

openssl genrsa -out bootstrapper.key 2048
openssl req -new -key bootstrapper.key -out bootstrapper.csr -subj "/CN=bootstrapper"
openssl x509 -req -in bootstrapper.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out bootstrapper.crt -days 365

