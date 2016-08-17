FROM golang:alpine

# Install Docker registry service.
RUN set -ex \
    && apk add --no-cache openssl make git

RUN go get github.com/docker/distribution/cmd/registry

EXPOSE 5000

ENTRYPOINT ["/go/bin/registry"]
CMD ["serve", "/bsroot/registry.yml"]

