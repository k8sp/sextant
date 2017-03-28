#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/ingress.template \
    -config-file /bsroot/html/static/ingress.yaml


/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/kubedns-controller.template \
    -config-file /bsroot/html/static/kubedns-controller.yaml


/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/kubedns-svc.template \
    -config-file /bsroot/html/static/kubedns-svc.yaml


/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/dnsmasq.conf.template \
    -config-file /bsroot/config/dnsmasq.conf


/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/default-backend.template \
    -config-file /bsroot/html/static/default-backend.yaml


/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/heapster-controller.template \
    -config-file /bsroot/html/static/heapster-controller.yaml

/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/influxdb-grafana-controller.template \
    -config-file /bsroot/html/static/influxdb-grafana-controller.yaml

/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/dashboard-controller.template \
    -config-file /bsroot/html/static/dashboard-controller.yaml
