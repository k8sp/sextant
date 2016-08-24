FROM alpine

# Docker registry service: https://docs.docker.com/registry/deploying/
ENV REGISTRY_HTTP_TLS_CERTIFICATE="/bsroot/bootstrapper.crt"
ENV REGISTRY_HTTP_TLS_KEY="/bsroot/bootstrapper.key"

ENTRYPOINT ["/bsroot/start.sh"]



