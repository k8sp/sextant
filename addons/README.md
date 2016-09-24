#### Sextant add-ons
[Kubernetes add-ons](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons) 是一组Replication Controllers或者Services，作为Kubernetes集群的一部分而存在的，例如 [skydns](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/dns),[ingress](https://github.com/kubernetes/contrib/tree/master/ingress/controllers/nginx) 等都属于add-ons的一部分。

Sextant addons模块会根据集群的 *cluster-desc.yaml* 配置文件以及相应add-on的配置模板，生成对应的add-on配置。

```
addone \
  --cluster-desc-file {cluster-desc.yaml} \
  --template-file {add-on template file}
  --config-file {add-on config file}
```
