FROM golang:alpine

RUN set -ex \
    && apk add --no-cache dnsmasq

ENTRYPOINT ["/usr/sbin/dnsmasq"]
# -k keeps dnsmasq in fore-ground, so we can run docker -it and see
# outputs from dnsmasq on the terminal.
CMD ["-k", "-C", "/bsroot/dnsmasq.conf"]
