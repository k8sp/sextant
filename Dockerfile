FROM golang:1.6.3-alpine
RUN set -ex && \
apk update && \
apk add --no-cache make git dnsmasq openssl docker && \
go get github.com/docker/distribution && \
cd /go/src/github.com/docker/distribution && \
make PREFIX=/go clean binaries && \
mkdir -p /etc/docker/registry && \
cp /go/src/github.com/docker/distribution/cmd/registry/config-dev.yml /etc/docker/registry/config.yml && \
cd .. && \
go get github.com/k8sp/auto-install/cloud-config-server
COPY pause:2.0.tar /opt/pause:2.0.tar
COPY hyperkube-adm64:v1.2.4.tar /opt/hyperkube-adm64:v1.2.4.tar
ADD start.sh /
VOLUME ["/var/lib/registry"]
ENTRYPOINT ["/start.sh"]
