FROM golang:alpine

# Install Docker registry service: https://docs.docker.com/registry/deploying/
RUN set -ex \
    && apk add --no-cache openssl make git

RUN go get github.com/docker/distribution/cmd/registry

ENV REGISTRY_HTTP_TLS_CERTIFICATE="/bsroot/bootstrapper.crt"
ENV REGISTRY_HTTP_TLS_KEY="/bsroot/bootstrapper.key"
  
EXPOSE 5000

ENTRYPOINT ["/go/bin/registry"]
CMD ["serve", "/bsroot/registry.yml"]

