#!/bin/bash

function ConfigDHCP() {
    cat << EOF
next-server $SelfIP;
filename "pxelinux.0";

subnet $Subnet netmask $Netmask {
    range $IPRangeLow $IPRangeHigh;
    option routers $Routers;
    option broadcast-address $Broadcast;
    option domain-name-servers $Nameservers; 

EOF

    for i in "${!MacToIP[@]}"; do
        mac=$(echo $i | sed 's/:/-/g');
        cat <<EOF
    host $mac   {
        hardware ethernet $i;
        fixed-address ${MacToIP[$i]};
    }
EOF
    done 

    echo "}"
}

