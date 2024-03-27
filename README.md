# Kustomize Manifests for Kubeflow on ppc64le
A repository for Kustomize manifests for Kubeflow on IBM Power (ppc64le).
These manifests base on the [official Kubeflow manifests](http://www.github.com/kubeflow/manifests/).

## Supported Distributions
- Red Hat OpenShift v4.5-v4.13 on ppc64le
- Vanilla Kubernetes v1.17-v1.26 on ppc64le

## Supported Kubeflow Versions
Please select appropriate tag:
- v1.8.0 (main)
- v1.7.0
- v1.6.0
- v1.5.0
- v1.4.1
- v1.3.0

### Pre-Requisites for Vanilla Kubernetes
Ensure that your ```kube-apiserver``` is initialized with settings for certificates to work, e.g.:
```
service-account-issuer: kubernetes.default.svc,
service-account-signing-key-file: /etc/kubernetes/ssl/sa.key
```
(see https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection)

Note that applying these settings depends on how you install the k8s cluster (e.g., kubeadmin/kubespray/minikube). Also the path for the signing key file may be different for you.

#### minikube
When initializing a cluster with minikube, these parameters may do the trick:
```
minikube start
...
--extra-config=apiserver.service-account-issuer=kubernetes.default.svc 
--extra-config=apiserver.service-account-signing-key-file=/var/lib/minikube/certs/sa.key
```

#### Kubespray
In Kubespray, modify ```kube_kubeadm_apiserver_extra_args```, e.g., like so:
```
cat << EOF >> roles/kubernetes/master/defaults/main/main.yml
kube_kubeadm_apiserver_extra_args: {
  service-account-issuer: kubernetes.default.svc,
  service-account-signing-key-file: /etc/kubernetes/ssl/sa.key
}
EOF
```

#### kubeadm
See: https://docs.nginx.com/nginx-service-mesh/get-started/kubernetes-platform/kubeadm/ for initializing or patching your existing cluster.

## Install
```
# select [main|v1.8.0|v1.7.0|v1.6.0|v1.5.0|v1.4.1|v1.3.0]
KUBEFLOW_VERSION=main
wget https://raw.githubusercontent.com/lehrig/kubeflow-ppc64le-manifests/${KUBEFLOW_VERSION}/install_kubeflow.sh
source install_kubeflow.sh
```
## Uninstall
```
# select [main|v1.8.0|v1.7.0|v1.6.0|v1.5.0|v1.4.1|v1.3.0]
KUBEFLOW_VERSION=main
wget https://raw.githubusercontent.com/lehrig/kubeflow-ppc64le-manifests/${KUBEFLOW_VERSION}/uninstall_kubeflow.sh
source uninstall_kubeflow.sh
```

## Release
1. Get relevant image updates from [official Kubeflow manifests](http://www.github.com/kubeflow/manifests/):
```
kustomize build example | yq eval '.. | select(has("image")) | ."image"'
```
2. Update these files accordingly:
- base/kustomization.yaml
- overlays/k8s/kustomization.yaml
- overlays/openshift/kustomization.yaml
3. Manually update:
- base/rewire-images-in-katib-config.yaml
- base/pipeline-params.env
- base/workflow-controller-deployment-patch.yaml
- base/rewire-inference-cm.yaml
- overlays/k8s/rewire-istio-images.yaml

