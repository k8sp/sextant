FROM golang:alpine

# Install required software packages.
RUN set -ex && \
apk update && \
apk add --no-cache make git dnsmasq openssl

# Upload Sextant Go programs and retrieve dependencies.
RUN mkdir -p /go/bin
COPY cloud-config-server /
COPY addons              /
COPY registry            /

# TODO(yi): Why do we need to create /go/static?
RUN mkdir /go/static

# NOTICE: change install.sh HTTP server ip:port when running entrypoint.sh
COPY entrypoint.sh /
VOLUME ["/var/lib/registry"]
WORKDIR "/go"
ENTRYPOINT ["/entrypoint.sh"]
