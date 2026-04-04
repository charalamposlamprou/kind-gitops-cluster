---
description: "Use when editing the Kind cluster configuration under infrastructure/cluster/. Covers node layout, port mappings, and the impact of cluster config changes on ingress and services."
applyTo: "infrastructure/cluster/**"
---

# Cluster Configuration

## Current layout (`kind-config.yaml`)

```
control-plane  (1 node)
  extraPortMappings:
    containerPort: 80  → hostPort: 8080
    containerPort: 443 → hostPort: 8443
worker         (3 nodes)
```

The kind cluster name is `local-k8s-cluster` (set in `Makefile`).

## Port mapping behaviour

The `extraPortMappings` on the control-plane node are **not** the primary traffic path for this cluster. Traffic flows:

```
browser → envoy (cloud-provider-kind, random high port) → HAProxy LoadBalancer svc → pods
```

The 8080/8443 mappings are a secondary access method (NodePort fallback). They do **not** affect `make urls` output, which always uses the envoy port.

## Changing the cluster config

Kind cluster config changes require a full cluster recreate — they cannot be applied in place:

```bash
make cluster-down    # deletes cluster + stops cloud-provider-kind
# edit infrastructure/cluster/kind-config.yaml
make cluster-up      # recreates cluster + starts cloud-provider-kind
make bootstrap       # re-installs Argo CD
make apps-install    # re-syncs all applications
```

**The envoy LoadBalancer port will change** after every `cluster-down/up`. Run `make urls` after to get the new URLs.

## Adding worker nodes

Add entries to `nodes:` with `role: worker`. No other change is needed — Argo CD and HAProxy are node-agnostic.

```yaml
nodes:
  - role: control-plane
    extraPortMappings: ...
  - role: worker
  - role: worker
  - role: worker
  - role: worker   # new worker
```

Note: more workers increase memory/CPU usage on dev machines. 3 workers is sufficient for the current workload.

## Changing host port mappings

If 8080 or 8443 are already in use on the host:

```yaml
extraPortMappings:
  - containerPort: 80
    hostPort: 9080    # change to any free port
  - containerPort: 443
    hostPort: 9443
```

Update `Makefile` NodePort targets accordingly if you use the NodePort access method (see [docs/ACCESSING-APPS.md](../../docs/ACCESSING-APPS.md)).

## What NOT to change

- `name` in `kind-config.yaml` — Kind doesn't read this field; the cluster name comes from `CLUSTER_NAME` in `Makefile`.
- `apiVersion: kind.x-k8s.io/v1alpha4` — do not bump; verify with `kind version` before changing.
