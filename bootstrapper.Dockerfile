FROM golang:alpine

# Install required software packages.
RUN set -ex && \
apk update && \
apk add --no-cache make git dnsmasq

# Build Sextant
COPY . /go/src/github.com/k8sp/sextant/
RUN go get github.com/k8sp/sextant/...

# Install Docker registry
RUN go get github.com/docker/distribution/... && \
cd /go/src/github.com/docker/distribution && \
make PREFIX=/go clean binaries && \
mkdir -p /etc/docker/registry && \
cp /go/src/github.com/docker/distribution/cmd/registry/config-dev.yml /etc/docker/registry/config.yml

COPY bootstrapper.sh /
ENTRYPOINT ["/bootstrapper.sh"]
