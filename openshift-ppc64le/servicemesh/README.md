# ServiceMesh controlplane

Deploy dedicated control plane for Kubeflow.

## Prerequisite

Create `oauth2-proxy.env` from `oauth2-proxy.env.tmpl`. You can choose to populate
credentials in the `oauth2-proxy.env` directly or export them as environment
variables.

It needs an OIDC application configuration to populate the `oauth2-proxy.env`.
It would be better to setup the oauth2-proxy with Redis as session store, which
requires following environment variables:

```
OAUTH2_PROXY_SESSION_STORE_TYPE=redis
OAUTH2_PROXY_REDIS_CONNECTION_URL=redis://<redis-host>:<port>/<db>
OAUTH2_PROXY_REDIS_PASSWORD=<redis-password>
# optional. only needed if redis is configured with self-signed cert
OAUTH2_PROXY_REDIS_INSECURE_SKIP_TLS_VERIFY=true
```

the `OAUTH2_PROXY_COOKIE_SECRET` variable should be encoded with base64. you can
generate one by running `openssl rand -base64 16`.

## Deploy

./kustomize --load-restrictor=LoadRestrictionsNone build ./openshift/servicemesh/ | oc apply -f -

## TODO

* be able to inject baseDomain 