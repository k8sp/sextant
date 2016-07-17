#! /bin/bash

# 颜色配置
Color_Text()
{
  echo -e " \e[0;$2m$1\e[0m"
}

Echo_Red()
{
  echo $(Color_Text "$1" "31")
}

Echo_Green()
{
  echo $(Color_Text "$1" "32")
}

Echo_Yellow()
{
  echo $(Color_Text "$1" "33")
}

Echo_Blue()
{
  echo $(Color_Text "$1" "34")
}

# 确认用户输入
display_selection()
{
    echo "目录中已存在 keypair 文件"
    user_selection="n"
    Echo_Yellow "确认重新生成?"
    read -p "默认为 n, 请输入 [y/n]: " user_selection
    case "${user_selection}" in
    [yY][eE][sS]|[yY])
        echo "开始生成 ..."
    ;;
    [nN][oO]|[nN])
        Echo_Blue "你选择了 n, 退出脚本!"
        exit 2
    ;;
    *)
        Echo_Blue "输入错误, 退出脚本!"
        exit 2
    esac
}


MASTER_HOST=$(awk -F= '/KUBERNETES_MASTER_IPV4/ {print $2}' environment)
# 检查当前目录是否存在keypair, 如存在提示是否覆盖重新生成
c=`ls *.pem 2>/dev/null|wc -l`
if [[ $c -ge 2 ]];then
    display_selection
    rm -f *.pem *.csr *.srl
    rm -f ../master/*.pem
    rm -f ../worker/*.pem
    rm -f ../kubectl/*.pem
fi
# 写入 MASTER_HOST IP 到 openssl.cnf
sed -i "s/IP\.2.*/IP.2 = $MASTER_HOST/" openssl.cnf

openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=kube-ca"

openssl genrsa -out apiserver-key.pem 2048
openssl req -new -key apiserver-key.pem -out apiserver.csr -subj "/CN=kube-apiserver" -config openssl.cnf
openssl x509 -req -in apiserver.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out apiserver.pem -days 365 -extensions v3_req -extfile openssl.cnf

openssl genrsa -out admin-key.pem 2048
openssl req -new -key admin-key.pem -out admin.csr -subj "/CN=kube-admin"
openssl x509 -req -in admin.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out admin.pem -days 365

\cp -fv ca.pem apiserver.pem apiserver-key.pem ../master
\cp -fv ca.pem ca-key.pem ../worker
\cp -fv ca.pem admin-key.pem admin.pem ../kubectl
\cp -fv environment ../worker
\cp -fv environment ../kubectl
