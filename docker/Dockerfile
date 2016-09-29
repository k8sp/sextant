FROM golang:alpine

# Install required software packages.
RUN set -ex && \
apk update && \
apk add --no-cache make git dnsmasq openssl docker

# Upload Sextant Go programs and retrieve dependencies.
RUN mkdir -p /go/bin
COPY cloud-config-server /go/bin/
COPY addons              /go/bin/
# Install Docker registry
RUN go get github.com/docker/distribution && \
cd /go/src/github.com/docker/distribution && \
make PREFIX=/go clean binaries && \
mkdir -p /etc/docker/registry && \
cp /go/src/github.com/docker/distribution/cmd/registry/config-dev.yml /etc/docker/registry/config.yml

# TODO(yi): Why do we need to create /go/static?
RUN mkdir /go/static

# NOTICE: change install.sh HTTP server ip:port when running entrypoint.sh
COPY entrypoint.sh /
VOLUME ["/var/lib/registry"]
WORKDIR "/go"
ENTRYPOINT ["/entrypoint.sh"]
