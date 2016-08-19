FROM golang:alpine

EXPOSE 8080

ENTRYPOINT ["/bsroot/cloud-config-server"]
CMD ["--cluster-desc-url=", \
    "--cluster-desc-file=/bsroot/cluster-desc.yml", \
    "--cc-template-url=", \
    "--cc-template-file=/bsroot/cloud-config.template", \
    "--ca-crt=/bsroot/ca.crt", \
    "--ca-key=/bsroot/ca.key"]
