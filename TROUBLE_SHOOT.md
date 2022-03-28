# Troubleshooting

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
