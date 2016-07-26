#!/bin/bash

source "./dhcp.bash"

function TestConfigDHCP() {
    SelfIP=192.168.2.10
    Subnet=192.168.2.0
    Netmask=255.255.255.0

    IPRangeLow=192.168.2.11 
    IPRangeHigh=192.168.2.249

    Routers=192.168.2.1
    Broadcast=192.168.2.255
    Nameservers="${SelfIP}, 8.8.8.8, 8.8.4.4"

    declare -A MacToIP=(
	["00:25:90:C0:F7:80"]="192.168.2.11"
	["00:25:90:C0:F6:EE"]="192.168.2.12"
    )

    result=$(ConfigDHCP);
    
    read -r -d '' expected << EOF
next-server 192.168.2.10;
filename "pxelinux.0";

subnet 192.168.2.0 netmask 255.255.255.0 {
    range 192.168.2.11 192.168.2.249;
    option routers 192.168.2.1;
    option broadcast-address 192.168.2.255;
    option domain-name-servers 192.168.2.10, 8.8.8.8, 8.8.4.4; 

    host 00-25-90-C0-F7-80   {
        hardware ethernet 00:25:90:C0:F7:80;
        fixed-address 192.168.2.11;
    }
    host 00-25-90-C0-F6-EE   {
        hardware ethernet 00:25:90:C0:F6:EE;
        fixed-address 192.168.2.12;
    }
}
EOF

    if [[  "$result" != "$expected" ]]; then
	echo "ERROR: result differs from expected"
    fi
}


TestConfigDHCP;
