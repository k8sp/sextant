FROM golang:alpine

# Install Docker registry service: https://docs.docker.com/registry/deploying/
RUN set -ex \
    && apk add --no-cache openssl make git
RUN go get github.com/docker/distribution/cmd/registry
ENV REGISTRY_HTTP_TLS_CERTIFICATE="/bsroot/bootstrapper.crt"
ENV REGISTRY_HTTP_TLS_KEY="/bsroot/bootstrapper.key"
EXPOSE 5000

# dnsmasq
RUN set -ex && apk add --no-cache dnsmasq

# cloud-config-server is supposed to be built using
# bsroot/build-cloud-config-server.bash and save into
# bsroot/cloud-config-server.

ENTRYPOINT ["/bsroot/start.sh"]



