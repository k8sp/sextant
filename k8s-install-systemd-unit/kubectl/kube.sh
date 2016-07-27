#! /bin/bash

# 获取配置文件 enviroment 中KUBERNETES_MASTER_IPV4 值
MASTER_HOST=$(awk -F= '/KUBERNETES_MASTER_IPV4/ {print $2}' environment)
CA_CERT=ca.pem
ADMIN_KEY=admin-key.pem
ADMIN_CERT=admin.pem

# 检查是否加入环境变量
kubectl > /dev/null 2>&1
is_in_path=$?
# 检查目录下是否有 kubectl
ls | grep -q 'kubectl'
is_found_kubectl=$?
if [[ ! $is_in_path -eq 0 ]]; then
    if [[ ! $is_found_kubectl -eq 0 ]]; then
        echo -e "Kubectl is not found in the current directory!\nDownload version for system https://coreos.com/kubernetes/docs/latest/configure-kubectl.html" && exit 1
    else
        mv kubectl /usr/local/bin/  
    fi
fi
# 检查当前目录下是否包含所需的 keypair
ls *.pem >/dev/null 2>&1
[[ ! $? -eq 0 ]] && echo "Not found admin keypair!!!" && exit 2

# 配置 kubectl
kubectl config set-cluster default-cluster --server=https://${MASTER_HOST} --certificate-authority=${CA_CERT}
kubectl config set-credentials default-admin --certificate-authority=${CA_CERT} --client-key=${ADMIN_KEY} --client-certificate=${ADMIN_CERT}
kubectl config set-context default-system --cluster=default-cluster --user=default-admin
kubectl config use-context default-system
