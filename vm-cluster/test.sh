#!/bin/bash
BSROOT="/Users/AndreYang/work/src/github.com/k8sp/sextant"
ntp_set=$(grep  '^set_ntp'  $BSROOT/cloud-config-server/template/cluster-desc.sample.yaml|cut -d : -f2)
echo "set_ntp:"$ntp_set
if [[ "$ntp_set" == " y" ]];then
 echo "ok"
else
 echo "faile"
fi
