#!/bin/bash
set -e
CERT_BASE_DIR=$1
CERT_ROLE=$2
IP_ADDR=$3
# Cert files fold tree
# ${CERT_BASE_DIR}
#		`_bin
#		  `_generate_cert.sh
#		|_etc
#		  `_openssl.cnf
#			|_worker-openssl.cnf
#		|_data
#		  `_ca.pem
#		  |_ca-key.pem
#		  |_$CERT_ROLE-$IP_ADDR
#		    `_worker-openssl.cnf|openssl.cnf
#		    |_apiserver.pem|apiserver-key.pem|worker.pem|worker-pem
#		
CERT_DIR_DATA=${CERT_BASE_DIR}/data/${CERT_ROLE}-${IP_ADDR}
CERT_DIR_ROOT=${CERT_BASE_DIR}/data
CERT_DIR_ETC=${CERT_BASE_DIR}/etc
case ${CERT_ROLE} in
	root)
		openssl genrsa -out ${CERT_DIR_ROOT}/ca-key.pem 2048
		openssl req -x509 -new -nodes -key ${CERT_DIR_ROOT}/ca-key.pem -days 10000 -out ${CERT_DIR_ROOT}/ca.pem -subj "/CN=kube-ca"
		;;
	
	master)
		# Generate API Server Keypair
		mkdir -p $CERT_DIR_DATA
		sed "s/<MASTER_HOST>/${IP_ADDR}/g" ${CERT_DIR_ETC}/openssl.cnf > ${CERT_DIR_DATA}/openssl.cnf
		openssl genrsa -out ${CERT_DIR_DATA}/apiserver-key.pem 2048
		openssl req -new -key ${CERT_DIR_DATA}/apiserver-key.pem -out ${CERT_DIR_DATA}/apiserver.csr -subj "/CN=kube-apiserver" -config ${CERT_DIR_DATA}/openssl.cnf
		openssl x509 -req -in ${CERT_DIR_DATA}/apiserver.csr -CA ${CERT_DIR_ROOT}/ca.pem -CAkey ${CERT_DIR_ROOT}/ca-key.pem -CAcreateserial -out ${CERT_DIR_DATA}/apiserver.pem -days 365 -extensions v3_req -extfile ${CERT_DIR_DATA}/openssl.cnf
		;;

	worker)
		# Generate Worker API Keypair
		mkdir -p $CERT_DIR_DATA
		sed "s/<WORKER_HOST>/${IP_ADDR}/g" ${CERT_DIR_ETC}/worker-openssl.cnf > ${CERT_DIR_DATA}/worker-openssl.cnf
		openssl genrsa -out ${CERT_DIR_DATA}/worker-key.pem 2048
    openssl req -new -key ${CERT_DIR_DATA}/worker-key.pem -out ${CERT_DIR_DATA}/worker.csr -subj "/CN=worker" -config ${CERT_DIR_DATA}/worker-openssl.cnf
    openssl x509 -req -in ${CERT_DIR_DATA}/worker.csr -CA ${CERT_DIR_ROOT}/ca.pem -CAkey ${CERT_DIR_ROOT}/ca-key.pem -CAcreateserial -out ${CERT_DIR_DATA}/worker.pem -days 365 -extensions v3_req -extfile ${CERT_DIR_DATA}/worker-openssl.cnf
		;;

	*)
		echo "Usage: generate_cert.sh BASE_DIR CERT_ROLE[root|master|worker] IP"
		exit 1
esac

#chmod 600 /etc/kubernetes/ssl/apiserver-key.pem
#chown root:root /etc/kubernetes/ssl/apiserver-key.pem
