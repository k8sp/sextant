#/bin/bash!

#准备bootstrapper安装环境
cd ../
./bsroot.sh vm-cluster/cluster-desc.yml.template

# TODO待这个bug修复后删除
#修复docker api client 和server 版本不一致的问题
sed -i '/FROM golang:alpine/a\ENV DOCKER_API_VERSION=1.22' ./Dockerfile

