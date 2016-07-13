#!/bin/bash


# 本脚本实现了在bare-metal上对kubernetes的master节点的自动安装。
# 使用本脚本前要确认coreos上的etcd2服务和flanneld服务已经正常运行。如果这两个服务不能正常运行，请参见：
# https://github.com/k8sp/bare-metal-coreos/pull/5/files/6f0c6ac9d371385be42f1bca990a69fe75309ad9?short_path=9189e72#diff-9189e729dd6dcd55d55a209facc4a6db

# 本脚本编写过程中主要参考了coreos官网安装k8s的step by step 教程，地址如下：

# 0. https://coreos.com/kubernetes/docs/latest/openssl.html
# 1. https://coreos.com/kubernetes/docs/latest/getting-started.html
# 2. https://coreos.com/kubernetes/docs/latest/deploy-master.html
# 3. https://coreos.com/kubernetes/docs/latest/deploy-workers.html
# 4. https://coreos.com/kubernetes/docs/latest/configure-kubectl.html
# 5. https://coreos.com/kubernetes/docs/latest/deploy-addons.html

# 本脚本代码主要基于：https://github.com/coreos/coreos-kubernetes 中的
# https://github.com/coreos/coreos-kubernetes/blob/master/multi-node/generic/controller-install.sh

# 本脚本阅读方法是：先看末尾，因为末尾包含了主流程，每一步都有注释解释。

# 本脚本以及相关配置文件预设：MasterNodeIP=10.10.10.191, WorkerNodeIP=10.10.10.192


export COREOS_PUBLIC_IPV4=$(LC_ALL=C ifconfig | grep 'inet ' | egrep -v '(127\.0\.0\.1)|(10\.1\..*)'|awk '{print $2}')
export MASTER_HOST=$COREOS_PUBLIC_IPV4
export ETCD_ENDPOINTS="http://${MASTER_HOST}:2379"
echo "ETCD_ENDPOINTS="$ETCD_ENDPOINTS

export K8S_VER=v1.2.4_coreos.cni.1
export HYPERKUBE_IMAGE_REPO=quay.io/coreos/hyperkube
export POD_NETWORK=10.2.0.0/16
export SERVICE_IP_RANGE=10.3.0.0/24
export K8S_SERVICE_IP=10.3.0.1
export DNS_SERVICE_IP=10.3.0.10
export USE_CALICO=false


function check_kubelet_install {
  systemctl status kubelet.service | grep 'not-found'
  if [[ ! $? -eq 0 ]]; then
    echo "kubelet service is installed."
    exit 0
  fi
}

function setup_tls {
  mkdir -p /etc/kubernetes/ssl
  rm -f /etc/kubernetes/ssl/*
  \cp -fuv ca.pem apiserver.pem apiserver-key.pem /etc/kubernetes/ssl
  chmod 600 /etc/kubernetes/ssl/*-key.pem
  chown root:root /etc/kubernetes/ssl/*-key.pem
}

function create_namespace {
    curl -H "Content-Type: application/json" -XPOST -d'{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"kube-system"}}' "http://127.0.0.1:8080/api/v1/namespaces"
    while [[ ! $? -eq 0 ]]; do
      echo "Create kube-system namespace fails, try again sleep 5s!"
      sleep 5
      curl -H "Content-Type: application/json" -XPOST -d'{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"kube-system"}}' "http://127.0.0.1:8080/api/v1/namespaces"
    done
}

function init_config {
    local REQUIRED=('ADVERTISE_IP' 'POD_NETWORK' 'ETCD_ENDPOINTS' 'SERVICE_IP_RANGE' 'K8S_SERVICE_IP' 'DNS_SERVICE_IP' 'K8S_VER' 'USE_CALICO')
    if [ -z $ADVERTISE_IP ]; then
        export ADVERTISE_IP=$COREOS_PUBLIC_IPV4
    fi

    for REQ in "${REQUIRED[@]}"; do
        if [ -z "$(eval echo \$$REQ)" ]; then
            echo "Missing required config value: ${REQ}"
            exit 1
        fi
    done

    if [ $USE_CALICO = "true" ]; then
        export K8S_NETWORK_PLUGIN="cni"
    else
        export K8S_NETWORK_PLUGIN=""
    fi
}

function init_template {
    local TEMPLATE=/etc/systemd/system/kubelet.service
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Service]
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests

Environment=KUBELET_VERSION=${K8S_VER}
Environment=KUBELET_ACI=${HYPERKUBE_IMAGE_REPO}
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --api-servers=http://127.0.0.1:8080 \
  --network-plugin-dir=/etc/kubernetes/cni/net.d \
  --network-plugin=${K8S_NETWORK_PLUGIN} \
  --register-node=true \
  --allow-privileged=true \
  --config=/etc/kubernetes/manifests \
  --hostname-override=${ADVERTISE_IP} \
  --cluster_dns=${DNS_SERVICE_IP} \
  --cluster_domain=cluster.local
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    }


    local TEMPLATE=/etc/systemd/system/calico-node.service
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
[Unit]
Description=Calico per-host agent
Requires=network-online.target
After=network-online.target

[Service]
Slice=machine.slice
Environment=CALICO_DISABLE_FILE_LOGGING=true
Environment=HOSTNAME=${ADVERTISE_IP}
Environment=IP=${ADVERTISE_IP}
Environment=FELIX_FELIXHOSTNAME=${ADVERTISE_IP}
Environment=CALICO_NETWORKING=false
Environment=NO_DEFAULT_POOLS=true
Environment=ETCD_ENDPOINTS=${ETCD_ENDPOINTS}
ExecStart=/usr/bin/rkt run --inherit-env --stage1-from-dir=stage1-fly.aci \
--volume=modules,kind=host,source=/lib/modules,readOnly=false \
--mount=volume=modules,target=/lib/modules \
--trust-keys-from-https quay.io/calico/node:v0.19.0
KillMode=mixed
Restart=always
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    }

    local TEMPLATE=/etc/kubernetes/manifests/kube-proxy.yaml
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-proxy
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-proxy
    image: ${HYPERKUBE_IMAGE_REPO}:$K8S_VER
    command:
    - /hyperkube
    - proxy
    - --master=http://127.0.0.1:8080
    - --proxy-mode=iptables
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF
    }

    local TEMPLATE=/etc/kubernetes/manifests/kube-apiserver.yaml
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-apiserver
    image: ${HYPERKUBE_IMAGE_REPO}:$K8S_VER
    command:
    - /hyperkube
    - apiserver
    - --bind-address=0.0.0.0
    - --etcd-servers=${ETCD_ENDPOINTS}
    - --allow-privileged=true
    - --service-cluster-ip-range=${SERVICE_IP_RANGE}
    - --secure-port=443
    - --advertise-address=${ADVERTISE_IP}
    - --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota
    - --tls-cert-file=/etc/kubernetes/ssl/apiserver.pem
    - --tls-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --client-ca-file=/etc/kubernetes/ssl/ca.pem
    - --service-account-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --runtime-config=extensions/v1beta1/deployments=true,extensions/v1beta1/daemonsets=true,extensions/v1beta1=true,extensions/v1beta1/thirdpartyresources=true
    ports:
    - containerPort: 443
      hostPort: 443
      name: https
    - containerPort: 8080
      hostPort: 8080
      name: local
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF
    }

    local TEMPLATE=/etc/kubernetes/manifests/kube-controller-manager.yaml
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  containers:
  - name: kube-controller-manager
    image: ${HYPERKUBE_IMAGE_REPO}:$K8S_VER
    command:
    - /hyperkube
    - controller-manager
    - --master=http://127.0.0.1:8080
    - --service-account-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --root-ca-file=/etc/kubernetes/ssl/ca.pem
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10252
      initialDelaySeconds: 15
      timeoutSeconds: 1
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF
    }

    local TEMPLATE=/etc/kubernetes/manifests/kube-scheduler.yaml
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-scheduler
    image: ${HYPERKUBE_IMAGE_REPO}:$K8S_VER
    command:
    - /hyperkube
    - scheduler
    - --master=http://127.0.0.1:8080
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10251
      initialDelaySeconds: 15
      timeoutSeconds: 1
EOF
    }

    local TEMPLATE=/srv/kubernetes/manifests/calico-policy-agent.yaml
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: calico-policy-agent
  namespace: calico-system
spec:
  hostNetwork: true
  containers:
    # The Calico policy agent.
    - name: k8s-policy-agent
      image: calico/k8s-policy-agent:v0.1.4
      env:
        - name: ETCD_ENDPOINTS
          value: "${ETCD_ENDPOINTS}"
        - name: K8S_API
          value: "http://127.0.0.1:8080"
        - name: LEADER_ELECTION
          value: "true"
    # Leader election container used by the policy agent.
    - name: leader-elector
      image: quay.io/calico/leader-elector:v0.1.0
      imagePullPolicy: IfNotPresent
      args:
        - "--election=calico-policy-election"
        - "--election-namespace=calico-system"
        - "--http=127.0.0.1:4040"

EOF
    }

    local TEMPLATE=/srv/kubernetes/manifests/kube-system.json
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
  "apiVersion": "v1",
  "kind": "Namespace",
  "metadata": {
    "name": "kube-system"
  }
}
EOF
    }

    local TEMPLATE=/srv/kubernetes/manifests/calico-system.json
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
  "apiVersion": "v1",
  "kind": "Namespace",
  "metadata": {
    "name": "calico-system"
  }
}
EOF
    }

    local TEMPLATE=/srv/kubernetes/manifests/network-policy.json
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
  "kind": "ThirdPartyResource",
  "apiVersion": "extensions/v1beta1",
  "metadata": {
    "name": "network-policy.net.alpha.kubernetes.io"
  },
  "description": "Specification for a network isolation policy",
  "versions": [
    {
      "name": "v1alpha1"
    }
  ]
}
EOF
    }

    local TEMPLATE=/srv/kubernetes/manifests/kube-dns-rc.json
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
  "apiVersion": "v1",
  "kind": "ReplicationController",
  "metadata": {
    "labels": {
      "k8s-app": "kube-dns",
      "kubernetes.io/cluster-service": "true",
      "version": "v11"
    },
    "name": "kube-dns-v11",
    "namespace": "kube-system"
  },
  "spec": {
    "replicas": 1,
    "selector": {
      "k8s-app": "kube-dns",
      "version": "v11"
    },
    "template": {
      "metadata": {
        "labels": {
          "k8s-app": "kube-dns",
          "kubernetes.io/cluster-service": "true",
          "version": "v11"
        }
      },
      "spec": {
        "containers": [
          {
            "command": [
              "/usr/local/bin/etcd",
              "-data-dir",
              "/var/etcd/data",
              "-listen-client-urls",
              "http://127.0.0.1:2379,http://127.0.0.1:4001",
              "-advertise-client-urls",
              "http://127.0.0.1:2379,http://127.0.0.1:4001",
              "-initial-cluster-token",
              "skydns-etcd"
            ],
            "image": "gcr.io/google_containers/etcd-amd64:2.2.1",
            "name": "etcd",
            "resources": {
              "limits": {
                "cpu": "100m",
                "memory": "500Mi"
              },
              "requests": {
                "cpu": "100m",
                "memory": "50Mi"
              }
            },
            "volumeMounts": [
              {
                "mountPath": "/var/etcd/data",
                "name": "etcd-storage"
              }
            ]
          },
          {
            "args": [
              "--domain=cluster.local"
            ],
            "image": "gcr.io/google_containers/kube2sky:1.14",
            "livenessProbe": {
              "failureThreshold": 5,
              "httpGet": {
                "path": "/healthz",
                "port": 8080,
                "scheme": "HTTP"
              },
              "initialDelaySeconds": 60,
              "successThreshold": 1,
              "timeoutSeconds": 5
            },
            "name": "kube2sky",
            "readinessProbe": {
              "httpGet": {
                "path": "/readiness",
                "port": 8081,
                "scheme": "HTTP"
              },
              "initialDelaySeconds": 30,
              "timeoutSeconds": 5
            },
            "resources": {
              "limits": {
                "cpu": "100m",
                "memory": "200Mi"
              },
              "requests": {
                "cpu": "100m",
                "memory": "50Mi"
              }
            }
          },
          {
            "args": [
              "-machines=http://127.0.0.1:4001",
              "-addr=0.0.0.0:53",
              "-ns-rotate=false",
              "-domain=cluster.local."
            ],
            "image": "gcr.io/google_containers/skydns:2015-10-13-8c72f8c",
            "name": "skydns",
            "ports": [
              {
                "containerPort": 53,
                "name": "dns",
                "protocol": "UDP"
              },
              {
                "containerPort": 53,
                "name": "dns-tcp",
                "protocol": "TCP"
              }
            ],
            "resources": {
              "limits": {
                "cpu": "100m",
                "memory": "200Mi"
              },
              "requests": {
                "cpu": "100m",
                "memory": "50Mi"
              }
            }
          },
          {
            "args": [
              "-cmd=nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null",
              "-port=8080"
            ],
            "image": "gcr.io/google_containers/exechealthz:1.0",
            "name": "healthz",
            "ports": [
              {
                "containerPort": 8080,
                "protocol": "TCP"
              }
            ],
            "resources": {
              "limits": {
                "cpu": "10m",
                "memory": "20Mi"
              },
              "requests": {
                "cpu": "10m",
                "memory": "20Mi"
              }
            }
          }
        ],
        "dnsPolicy": "Default",
        "volumes": [
          {
            "emptyDir": {},
            "name": "etcd-storage"
          }
        ]
      }
    }
  }
}
EOF
    }

    local TEMPLATE=/srv/kubernetes/manifests/kube-dns-svc.json
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
  "apiVersion": "v1",
  "kind": "Service",
  "metadata": {
    "name": "kube-dns",
    "namespace": "kube-system",
    "labels": {
      "k8s-app": "kube-dns",
      "kubernetes.io/name": "KubeDNS",
      "kubernetes.io/cluster-service": "true"
    }
  },
  "spec": {
    "clusterIP": "$DNS_SERVICE_IP",
    "ports": [
      {
        "protocol": "UDP",
        "name": "dns",
        "port": 53
      },
      {
        "protocol": "TCP",
        "name": "dns-tcp",
        "port": 53
      }
    ],
    "selector": {
      "k8s-app": "kube-dns"
    }
  }
}
EOF
    }

    local TEMPLATE=/srv/kubernetes/manifests/heapster-dc.json
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
  "apiVersion": "extensions/v1beta1",
  "kind": "Deployment",
  "metadata": {
    "labels": {
      "k8s-app": "heapster",
      "kubernetes.io/cluster-service": "true",
      "version": "v1.0.2"
    },
    "name": "heapster-v1.0.2",
    "namespace": "kube-system"
  },
  "spec": {
    "replicas": 1,
    "selector": {
      "matchLabels": {
        "k8s-app": "heapster",
        "version": "v1.0.2"
      }
    },
    "template": {
      "metadata": {
        "labels": {
          "k8s-app": "heapster",
          "version": "v1.0.2"
        }
      },
      "spec": {
        "containers": [
          {
            "command": [
              "/heapster",
              "--source=kubernetes.summary_api:''",
              "--metric_resolution=60s"
            ],
            "image": "gcr.io/google_containers/heapster:v1.0.2",
            "name": "heapster",
            "resources": {
              "limits": {
                "cpu": "100m",
                "memory": "250Mi"
              },
              "requests": {
                "cpu": "100m",
                "memory": "250Mi"
              }
            }
          },
          {
            "command": [
              "/pod_nanny",
              "--cpu=100m",
              "--extra-cpu=0m",
              "--memory=250Mi",
              "--extra-memory=4Mi",
              "--threshold=5",
              "--deployment=heapster-v1.0.2",
              "--container=heapster",
              "--poll-period=300000"
            ],
            "env": [
              {
                "name": "MY_POD_NAME",
                "valueFrom": {
                  "fieldRef": {
                    "fieldPath": "metadata.name"
                  }
                }
              },
              {
                "name": "MY_POD_NAMESPACE",
                "valueFrom": {
                  "fieldRef": {
                    "fieldPath": "metadata.namespace"
                  }
                }
              }
            ],
            "image": "gcr.io/google_containers/addon-resizer:1.0",
            "name": "heapster-nanny",
            "resources": {
              "limits": {
                "cpu": "50m",
                "memory": "100Mi"
              },
              "requests": {
                "cpu": "50m",
                "memory": "100Mi"
              }
            }
          }
        ]
      }
    }
  }
}
EOF
    }

    local TEMPLATE=/srv/kubernetes/manifests/heapster-svc.json
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
  "kind": "Service",
  "apiVersion": "v1",
  "metadata": {
    "name": "heapster",
    "namespace": "kube-system",
    "labels": {
      "kubernetes.io/cluster-service": "true",
      "kubernetes.io/name": "Heapster"
    }
  },
  "spec": {
    "ports": [
      {
        "port": 80,
        "targetPort": 8082
      }
    ],
    "selector": {
      "k8s-app": "heapster"
    }
  }
}
EOF
    }

    local TEMPLATE=/etc/kubernetes/cni/net.d/10-calico.conf
    [ -f $TEMPLATE ] || {
        echo "TEMPLATE: $TEMPLATE"
        mkdir -p $(dirname $TEMPLATE)
        cat << EOF > $TEMPLATE
{
    "name": "calico",
    "type": "flannel",
    "delegate": {
        "type": "calico",
        "etcd_endpoints": "$ETCD_ENDPOINTS",
        "log_level": "none",
        "log_level_stderr": "info",
        "hostname": "${ADVERTISE_IP}",
        "policy": {
            "type": "k8s",
            "k8s_api_root": "http://127.0.0.1:8080/api/v1/"
        }
    }
}
EOF
    }

}

# Check kubelet installation
check_kubelet_install

# generate tls assets and put them in /etc/kubernetes/ssl
setup_tls

# init and check the configure value
init_config
echo "ADVERTISE_IP="$ADVERTISE_IP

# generate kubelet service configure files and save them into /etc/kubernetes/manifests
init_template
systemctl daemon-reload


# start kubelet service
systemctl daemon-reload
systemctl enable kubelet
systemctl restart kubelet

# sleep 3 minutes, and then create namespace
sleep 3m
create_namespace
