# Troubleshooting

## Init:CrashLoopBackOff 

### Symptoms
Pods failing with ```Init:CrashLoopBackOff```.

### Diagnosis
```
oc logs centraldashboard-*** -n kubeflow -c istio-init
```
gives
```
iptables-restore --noflush /tmp/iptables-rules-1648485349812569495.txt081246391
iptables-restore v1.6.1: iptables-restore: unable to initialize table 'nat'
```

### Treatment
```
modprobe br_netfilter ; modprobe nf_nat ; modprobe xt_REDIRECT ; modprobe xt_owner; modprobe iptable_nat; modprobe iptable_mangle; modprobe iptable_filter
```
(see https://github.com/istio/istio/issues/23009)


## Namespace not terminating

### Symptoms
Upon deletion, a namespace remains in ```terminating``` state.

### Diagnosis

```
oc get ns
```

Checking if any apiservice is unavailable and hence doesn't serve its resources:
```
kubectl get apiservice|grep False
```
(see https://github.com/kubernetes/kubernetes/issues/60807#issuecomment-524772920)


Finding all resources that still exist via:
```
oc api-resources --verbs=list --namespaced -o name | xargs -t -n 1 oc get --show-kind --ignore-not-found -n $PROJECT_NAME 
```
(see https://access.redhat.com/solutions/4165791)

Example issue (invalid CA bundle):
```
oc get --show-kind --ignore-not-found -n istio-system inferenceservices.serving.kserve.io 
Error from server (InternalError): Internal error occurred: error resolving resource
```

Example issue (resources remaining in namespace):
```
oc get --show-kind --ignore-not-found -n user-example-com servicemeshmembers.maistra.io 
NAME                                   CONTROL PLANE           READY   AGE
servicemeshmember.maistra.io/default   istio-system/kubeflow   False   2d23h
```

Confirm:
```
oc get -n istio-system inferenceservices.serving.kserve.io
```

Understand:
```
oc describe crd inferenceservices.serving.kserve.io
```

Check for invalid CA bundle:
```
oc get crd inferenceservices.serving.kserve.io -o yaml | grep caBundle:
```
(see https://access.redhat.com/solutions/6913481)

### Treatment

Force-Delete buggy CRD:
```
kubectl patch crd/inferenceservices.serving.kserve.io -p '{"metadata":{"finalizers":[]}}' --type=merge
```
(see https://github.com/kubernetes/kubernetes/issues/60538#issuecomment-369099998)


Follow cleanup guidelines.
(see https://docs.openshift.com/container-platform/4.11/service_mesh/v2x/removing-ossm.html#ossm-remove-cleanup_removing-ossm)

Force-Delete buggy CRD:
```
kubectl patch crd/servicemeshmembers.maistra.io -p '{"metadata":{"finalizers":[]}}' --type=merge
```
## failed calling webhook "webhook.cert-manager.io"

### Symptoms
When installing Kubeflow, you get messages like this:
```
Error from server (InternalError): error when creating "/opt/kubeflow/git/kubeflow-ppc64le-manifests/overlays/openshift": Internal error occurred: failed calling webhook "webhook.cert-manager.io": failed to call webhook: Post "https://cert-manager-webhook.cert-manager.svc:443/mutate?timeout=10s": x509: certificate signed by unknown authority
```

### Diagnosis
```
oc logs -n cert-manager cert-manager-***
```
gives
```
E1130 16:41:00.253828    1 leaderelection.go:325] error retrieving resource lock kube-system/cert-manager-controller: configmaps "cert-manager-controller" is forbidden: User "system:serviceaccount:cert-manager:cert-manager" cannot get resource "configmaps" in API group "" in the namespace "kube-system"
```

```
oc logs -n cert-manager cert-manager-cainjector-***
```
gives something similar but for service account ```cert-manager-cainjector```.

### Treatment
HotFix (not recommended for production; determine more fine-grained policies):
```
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:cert-manager:cert-manager
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:cert-manager:cert-manager-cainjector
```

## Kubernetes resources are missing (e.g., Subscriptions)

### Symptoms
Trying to get a resource even on all namespaces (e.g., `oc get Subscription -A`) yields:
```
No resources found
```
Even though it should be there.

### Diagnosis
Find out the API Group, e.g.:
```
kubectl api-resources -o wide | grep -i Subscription
```

This may give multiple resources with the same name, e.g.:
```
subscriptions                         sub                  messaging.knative.dev/v1                      true         Subscription                         [delete deletecollection get list patch create update watch]
subscriptions                         sub,subs             operators.coreos.com/v1alpha1                 true         Subscription                         [delete deletecollection get list patch create update watch]
```

### Treatment
Use fully qualified resource name when getting resources:
```
oc get Subscription.operators.coreos.com -A
```
