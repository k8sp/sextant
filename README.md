[![Build Status](https://travis-ci.org/k8sp/sextant.svg?branch=master)](https://travis-ci.org/k8sp/sextant.svg?branch=master)

#Sextant
<img src="logo/Sextant.png" width="250">

Sextant initialize a cluster installed with CoreOS and Kubernetes using PXE.

# Enviroment setup
Bootstrapper will be running on a machine(AKA: bootstrapper server), which need to meet the following requirements

1. The kubernetes machines waiting for install need to be connected with bootstrapper server.
2. Bootstrapper server is a linux server with docker daemon(1.11 or later) installed.
3. Have root access of the bootstrapper server.

# Configurations and download image files that bootstrapper needs.

***The following steps will prepare the environment, generate configurations and build docker images.***
* if there's no internet access on the bootstrapper server, you can copy the pre-donwloaded `/bsroot` directory to it.

After getting the sextant code, you need to plan the cluster installation details by editing `cloud-config-server/template/cluster-desc.sample.yaml`. Then build bootstrapper to the `./bsroot` directory.

```
go get -u -d github.com/k8sp/sextant/...
cd $GOPATH/src/github.com/k8sp/sextant
vim cloud-config-server/template/cluster-desc.sample.yaml
./bsroot.sh cloud-config-server/template/cluster-desc.sample.yaml
```

# Uploaded to the bootstrapper server

If the above steps is done on the bootstrapper server, you can skip this step.

1. Packing direcotry `./bsroot`: `tar czvf bsroot.tar.gz ./bsroot`
2. Upload `bsroot.tar.gz` to the bootstrapper server.(using tools such as SCP or FTP)
3. Extract `bsroot.tar.gz` to `/` directory on bootstrapper server.

# Start bootstrapper

```
ssh root@bootstrapper
cd /bsroot
./start_bootstrapper_container.sh /bsroot
```

# Setup kubernetes cluster using the bootstrapper

Just set kubernetes nodes boot through PXE, reboot the machine, then it will completed Kubernetes and Ceph installation automatically.

# Using kubernetes cluster

## Configurate kubectl client

```
scp root@bootstrapper:/bsroot/setup-kubectl.bash ./
./setup-kubectl.bash
```

## Verify kubectl configuration and connection

Execute the following command, verify whether the client has been property configured according to the return result.

```
bootstrapper ~ # ./kubectl get nodes
NAME                STATUS                     AGE
08-00-27-4a-2d-a1   Ready,SchedulingDisabled   1m
```

## Using Ceph cluster

After the cluster installation is complete, you can use the following command to obtain admin keyring for the later use.

```
etcdctl --endpoints http://08-00-27-ef-d2-12:2379 get /ceph-config/ceph/adminKeyring
```

For example, mount a directory with CephFS.

```
mount -t ceph 192.168.8.112:/ /ceph -o name=admin,secret=[your secret]
```

# Cluster maintenance

## How to updating the cert after the cluster is running for some time.

1. Edit the confuration `openssl.cnf` in `certgen.go`.

```
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
DNS.5 = 10.10.10.201
IP.1 = 10.100.0.1
```
2. Regenerating api-server.pem and other files according the openssl.cnf: https://coreos.com/kubernetes/docs/latest/openssl.html
3. Restart master processes, including api-server,controller-manager,scheduler,kube-proxy
4. Delete default secret under kube-system/default namesapce using kubectl delete secret
5. Resubmit failed service.
