#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/ingress.template \
    -config-file /bsroot/html/static/addons-config/ingress.yaml


/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/kubedns-controller.template \
    -config-file /bsroot/html/static/addons-config/kubedns-controller.yaml


/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/kubedns-svc.template \
    -config-file /bsroot/html/static/addons-config/kubedns-svc.yaml

/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/dnsmasq.hosts.template \
    -config-file /bsroot/config/dnsmasq.hosts

/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/dnsmasq.conf.template \
    -config-file /bsroot/config/dnsmasq.conf


/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/default-backend.template \
    -config-file /bsroot/html/static/addons-config/default-backend.yaml


/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/heapster-controller.template \
    -config-file /bsroot/html/static/addons-config/heapster-controller.yaml

/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/influxdb-grafana-controller.template \
    -config-file /bsroot/html/static/addons-config/influxdb-grafana-controller.yaml

/go/bin/addons -cluster-desc-file /cluster-desc.yaml \
    -template-file /addons/template/dashboard-controller.template \
    -config-file /bsroot/html/static/addons-config/dashboard-controller.yaml
