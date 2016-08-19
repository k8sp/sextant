FROM golang:alpine
RUN set -ex && \
apk update && \
apk add --no-cache make git dnsmasq openssl docker && \
go get github.com/docker/distribution && \
cd /go/src/github.com/docker/distribution && \
make PREFIX=/go clean binaries && \
mkdir -p /etc/docker/registry && \
cp /go/src/github.com/docker/distribution/cmd/registry/config-dev.yml /etc/docker/registry/config.yml && \
go get github.com/k8sp/auto-install/cloud-config-server && \
mkdir /go/static
COPY hyperkube-amd64_v1.2.4.tar /opt/hyperkube-amd64_v1.2.4.tar
COPY pause_2.0.tar /opt/pause_2.0.tar
# NOTICE: change install.sh HTTP server ip:port when running start.sh
ADD cloud-config-server/install.sh /go/static
ADD start.sh /
VOLUME ["/var/lib/registry"]
WORKDIR "/go"
ENTRYPOINT ["/start.sh"]
