FROM golang:alpine
RUN set -ex && \
apk update && \
apk add --no-cache make git dnsmasq openssl && \
go get github.com/docker/distribution && \
cd /go/src/github.com/docker/distribution && \
make PREFIX=/go clean binaries && \
mkdir -p /etc/docker/registry && \
cp /go/src/github.com/docker/distribution/cmd/registry/config-dev.yml /etc/docker/registry/config.yml && \
cd .. && \
go get github.com/k8sp/auto-install/cloud-config-server
ADD start.sh /
VOLUME ["/var/lib/registry"]
ENTRYPOINT ["/start.sh"]
