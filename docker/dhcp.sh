#!/usr/bin/env sh

op="${1:-op}"
mac="${2:-mac}"
ip="${3:-ip}"
hostname="${4}"

fileNameForMac () {
  echo $1| tr ':' '-'
}
filename=$( fileNameForMac $mac )
filepath="/bsroot/dnsmasq/hosts.d/${filename}"

if [[ $op == "add" ||  $op == "old" ]]
then
  if [ -f $filepath ]
  then
    rm -f $filepath
  fi
  cat > $filepath <<EOF
$ip $filename
EOF
  if [[ $hostname != "" && $filename != $hostname ]]
  then
    echo "$ip $hostname" >> $filepath
  fi
fi

if [[ $op == "del" ]]; then
 rm -f $filepath
fi
