---
description: "Use when adding, editing, or reviewing infrastructure components under infrastructure/. Covers Argo CD Application structure, Helm values, sync-wave ordering, namespace conventions, and kustomization registration."
applyTo: "infrastructure/**"
---

# Infrastructure Components

## Structure

Every infrastructure component lives under `infrastructure/<name>/` and minimally contains:
- `<name>-application.yaml` — Argo CD `Application` pointing to a Helm chart or Kustomize path
- `kustomization.yaml` — lists all resources in the directory

The component's `kustomization.yaml` entry must be added to `infrastructure/kustomization.yaml` to be picked up by `infra-app`.

## Argo CD Application template (Helm chart)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <component>
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"   # see wave ordering below
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: <target-namespace>
  source:
    repoURL: https://<helm-chart-repo>
    chart: <chart-name>
    targetRevision: <chart-version>     # pin to exact chart version
    helm:
      releaseName: <release-name>
      values: |
        # inline Helm values (no separate values file)
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Sync-wave ordering

Argo CD applies resources in ascending wave order within the same sync operation. Current convention:

| Wave | Components |
|------|-----------|
| `-1` | prometheus-crds (CRDs must exist before operators) |
| `0` | Everything else (default; omit the annotation) |

- Always install CRD-only apps at wave `-1` if a later app depends on those CRDs.
- Do **not** assign positive waves unless strictly necessary — default wave `0` is fine for most components.

## Namespace conventions

| Namespace | Used for |
|-----------|---------|
| `argocd` | Argo CD itself |
| `monitoring` | Prometheus, Grafana, Loki, Tempo, OTel Collector |
| `networking` | HAProxy ingress controller |
| `sealed-secrets` | Sealed Secrets controller |
| `argo-rollouts` | Argo Rollouts controller |
| `apps` | All application microservices |

Always use `syncOptions: [CreateNamespace=true]` rather than committing a `Namespace` manifest, unless the namespace needs custom labels/annotations.

## Helm values convention

Keep all Helm values **inline** in the `Application` `spec.source.helm.values` field. Do not create separate `values.yaml` files — inline values keep everything in one place for GitOps review.

## Adding a new infrastructure component

1. Create `infrastructure/<name>/` with `<name>-application.yaml` and `kustomization.yaml`.
2. Add `- <name>/` to `infrastructure/kustomization.yaml` resources.
3. If the component installs CRDs that another component depends on, add `sync-wave: "-1"` annotation and ensure the dependent is at wave `0` or higher.
4. Commit to a feature branch, open a PR to `main` — CI validates the kustomization build automatically.

## What is NOT managed by Argo CD

- `infrastructure/cloud-provider/` — runs as Docker Compose on the host. Use `make cloud-provider-up/down`.
- `bootstrap/` — applied once imperatively via `make bootstrap`. Never re-apply manually.
