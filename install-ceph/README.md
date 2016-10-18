# Using ceph rbd on kubernetes on coreos

## Environment Preparation
Setup ceph client environment on one of your coreos machine(usually the master).

create a file /opt/bin/rbd and put paste lines below.
```
#!/bin/bash
docker run -i --rm \
--privileged \
--pid host \
--net host \
--volume /dev:/dev \
--volume /sys:/sys \
--volume=/sbin/modprobe:/sbin/modprobe \
--volume=/lib/modules:/lib/modules \
--volume /etc/ceph:/etc/ceph \
--volume /var/lib/ceph:/var/lib/ceph \
--entrypoint $(basename $0) \
ceph/rbd "$@"
```
Make the script runnable, and make sure `/opt/bin` is under PATH env:
```
chmod +x /opt/bin/rbd
```
If ceph is has already been installed on the current machine, we will have
`/etc/ceph` directory containing `ceph.conf` and your keyring. If not, copy
the `/etc/ceph` configurations from your ceph installation.

Then you'll be able to run `rbd` command to create, rm and list images.

## Create your rbd image
Run `rbd [--user myuser] create [imagename] --size [image size MB] --pool [poolname]`
to create rbd image under your pool,
like: `rbd create bar --size 1024 --pool swimmingpool`.

Then run `rbd ls` will list the images you've created.

According to issues mentioned [here](http://www.zphj1987.com/2016/06/07/rbd无法map(rbd-feature-disable)/)
we need to disable the new features of rbd images in order to run under
kubernetes:
```
rbd feature disable mypool/myimage deep-flatten
rbd feature disable mypool/myimage fast-diff
rbd feature disable mypool/myimage object-map
rbd feature disable mypool/myimage exclusive-lock
```

## Mount rbd volume in a kubernetes pod
Do the following steps to create a kubernetes secret for cephx.

Get the base64 encoded keyring:
```
echo "AQBAMo1VqE1OMhAAVpERPcyQU5pzU6IOJ22x1w==" | base64
QVFCQU1vMVZxRTFPTWhBQVZwRVJQY3lRVTVwelU2SU9KMjJ4MXc9PQo=
```

Edit your ceph-secret.yml with the base64 key:
```
apiVersion: v1
kind: Secret
metadata:
  name: ceph-secret
data:
  key: QVFCQU1vMVZxRTFPTWhBQVZwRVJQY3lRVTVwelU2SU9KMjJ4MXc9PQo=
```

Add your secret to Kubernetes:
```
kubectl create -f secret/ceph-secret.yaml
kubectl get secret
NAME                  TYPE                                  DATA
ceph-secret           Opaque                                1
```

Now, we edit our rbd-with-secret.json pod file.
This file describes the content of your pod:
```
{
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
        "name": "rbd1"
    },
    "spec": {
        "containers": [
            {
                "name": "rbd-test001",
                "image": "nginx",
                "volumeMounts": [
                    {
                        "mountPath": "/mnt/rbd",
                        "name": "rbdpd"
                    }
                ]
            }
        ],
        "nodeSelector": {
                "role": "worker"
        },
        "volumes": [
            {
                "name": "rbdpd",
                "rbd": {
                    "monitors": [
                                                        "192.168.119.150:6789",
                                                        "192.168.119.151:6789",
                                                        "192.168.119.152:6789"
                                 ],
                    "pool": "lgk8s",
                    "image": "nginx",
                    "user": "lgk8s",
                    "secretRef": {
                        "name": "ceph-secret-lugu-wuyi"
                    },
                    "fsType": "ext4",
                    "readOnly": true
                }
            }
          ]
        }
      }
```
Now it’s time to fire it up your pod:
```
kubectl create -f rbd-with-secret.json
kubectl get pods
NAME      READY     REASON    RESTARTS   AGE
rbd2      1/1       Running   0          1m
```
