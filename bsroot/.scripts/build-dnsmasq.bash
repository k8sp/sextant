#!/bin/bash

DNSMASQ_VERSION=2.76
wget -c http://www.thekelleys.org.uk/dnsmasq/dnsmasq-$DNSMASQ_VERSION.tar.gz
tar xzf dnsmasq-$DNSMASQ_VERSION.tar.gz
(
    cd dnsmasq-$DNSMASQ_VERSION
    sed -i.bak 's/^LDFLAGS.*=.*$/LDFLAGS=-static -static-libgcc/' Makefile
)
docker run --rm -it -v $(pwd)/dnsmasq-$DNSMASQ_VERSION:/dnsmasq -w /dnsmasq gcc make
mv dnsmasq-$DNSMASQ_VERSION/src/dnsmasq .
rm -rf dnsmasq-$DNSMASQ_VERSION

