FROM distribution/registry

# Install required software packages.
RUN set -ex && \
apk update && \
apk add dnsmasq openssl

# Upload Sextant Go programs and retrieve dependencies.
RUN mkdir -p /go/bin
COPY cloud-config-server /go/bin

# NOTICE: change install.sh HTTP server ip:port when running entrypoint.sh
COPY entrypoint.sh /
COPY dhcp.sh /
VOLUME ["/var/lib/registry"]
WORKDIR "/go"
ENTRYPOINT ["/entrypoint.sh"]
