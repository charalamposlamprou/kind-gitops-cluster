---
description: "General engineering guidelines for this project — YAML conventions, resource naming, label standards, PR checklist, and onboarding. Applies to all files."
applyTo: "**"
---

# General Engineering Guidelines

## YAML conventions (all manifests)

- **Always declare `namespace`** explicitly in every resource `metadata` — never rely on kustomization namespace injection alone.
- **Pin all versions**: container image tags (`node:20-alpine`, not `node:latest`), Helm `targetRevision` (exact semver), Argo CD `targetRevision` (`HEAD` or a branch name — never omit).
- **No `kind: Deployment`** for microservices — use `kind: Rollout` (`argoproj.io/v1alpha1`).
- **No `kind: Secret`** committed to Git — always use `kind: SealedSecret`. See [secrets.instructions.md](secrets.instructions.md).
- **Resource limits required** on every container:
  ```yaml
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 400m
      memory: 256Mi
  ```
- **2-space indentation**, no tabs.

## Resource naming conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| Rollout / Deployment | `<service-name>` | `microservice-a` |
| Active Service | `service-<name>` | `service-a` |
| Preview Service | `service-<name>-preview` | `service-a-preview` |
| Ingress | `<name>-ingress` | `microservice-a-ingress` |
| ConfigMap (app code) | `<name>-app` | `microservice-a-app` |
| Argo CD Application | `<name>` | `microservice-a` |
| SealedSecret | `sealed-<secret-name>` | `sealed-db-credentials` |
| Dashboard ConfigMap | `<slug>-dashboard` | `microservices-metrics-dashboard` |

## Label conventions

Every workload resource (Rollout, Pod template) must carry both labels:

```yaml
labels:
  app.kubernetes.io/name: <service-name>
  app.kubernetes.io/part-of: microservices
```

Do not use custom/ad-hoc labels as the primary selector — use `app: <name>` as the selector label and the `app.kubernetes.io/*` labels for observability grouping.

## Namespace conventions

| Namespace | Contents |
|-----------|---------|
| `apps` | All microservices |
| `monitoring` | Prometheus, Grafana, Loki, Tempo, OTel Collector |
| `networking` | HAProxy ingress controller |
| `argocd` | Argo CD |
| `sealed-secrets` | Sealed Secrets controller |
| `argo-rollouts` | Argo Rollouts controller |

Never put microservices in `default`. Always include `syncOptions: [CreateNamespace=true]` in Argo CD Applications.

## PR review checklist

Before approving a PR, verify:

- [ ] **CI passes** — `k8s-validation` workflow (kustomize build + kubeconform) is green
- [ ] **`kustomization.yaml` updated** — any new file is registered in its local `kustomization.yaml`
- [ ] **CHANGELOG.md updated** — entry added under the correct version and section
- [ ] **Conventional commit** — message follows `feat:` / `fix:` / `chore:` format
- [ ] **No raw `kind: Secret`** in the diff
- [ ] **`targetRevision: HEAD`** on new Argo CD Applications (not a feature branch)
- [ ] **Resource limits present** on any new container spec
- [ ] **No hardcoded ports or URLs** — envoy port changes on cluster recreate

## Onboarding (first-time setup)

Prerequisites: Docker Desktop, `kubectl`, `kind`, `make`, `git`, `kubeseal` (for secrets).

```bash
git clone https://github.com/charalamposlamprou/kind-gitops-cluster.git
cd kind-gitops-cluster
make cluster-up     # create kind cluster + start cloud-provider-kind
make bootstrap      # install Argo CD + apply root App-of-Apps
make apps-install   # sync all applications
make urls           # get all service URLs
make argocd-password  # get Argo CD admin password
```

Full access method guide: [docs/ACCESSING-APPS.md](../docs/ACCESSING-APPS.md).

Once set up, verify everything is healthy:

```bash
make argocd-status  # all apps should show Synced + Healthy
make test-ingress   # smoke-test all routes
make test-otel      # validate traces/metrics/logs pipeline
```
