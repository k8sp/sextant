FROM golang:alpine

# Install Docker registry service.
RUN set -ex \
    && apk add --no-cache openssl make git

RUN go get github.com/docker/distribution/cmd/registry
WORKDIR /go/src/github.com/docker/distribution
RUN make PREFIX=/tmp clean binaries

EXPOSE 5000

ENTRYPOINT ["/tmp/bin/registry"]
CMD ["serve", "/bsroot/registry.yml"]

