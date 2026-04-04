---
name: validate-cluster
description: "Validate the full GitOps cluster health: Argo CD app sync status, ingress routes, and the OpenTelemetry pipeline (traces→Tempo, metrics→Prometheus, logs→Loki). Use when verifying a deployment, after cluster recreate, or when debugging a broken environment."
argument-hint: "Optional: name of a specific app to check (e.g. microservice-a)"
---

# Validate Cluster

End-to-end health check for the kind GitOps cluster.

## When to Use

- After `make cluster-up` + `make bootstrap` + `make apps-install`
- After merging a PR and wanting to confirm Argo CD synced successfully
- When something seems broken and you need a fast triage
- Before/after a blue-green rollout promotion

## Procedure

Run the checks in order. Each step depends on the previous being healthy.

### Step 1 — Argo CD application status

```bash
make argocd-status
```

All applications should show `Synced` + `Healthy`. If any show `Degraded`, `OutOfSync`, or `Missing`:

```bash
# Get detailed sync error for a specific app
kubectl describe application <name> -n argocd

# Force a hard refresh
kubectl annotate application <name> -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

### Step 2 — Service URLs

```bash
make urls
```

Copy the printed URLs — you'll need the current envoy port for Step 3.

### Step 3 — Ingress smoke test

```bash
make test-ingress
```

Runs [scripts/test-ingress.sh](../../scripts/test-ingress.sh) — expects HTTP 200 from all ingress routes. If it fails:

- Confirm `cloud-provider-kind` is running: `docker ps | grep cloud-provider`
- Restart if needed: `make cloud-provider-restart`
- Check HAProxy pod: `kubectl get pods -n networking`

### Step 4 — OTel pipeline (traces / metrics / logs)

```bash
make test-otel
```

Runs [scripts/test-otel.sh](../../scripts/test-otel.sh) — validates:
- Traces reach Tempo
- Metrics reach Prometheus
- Logs reach Loki

If OTel checks fail:

```bash
# Check OTel Collector DaemonSet
kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-collector

# Tail collector logs for errors
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --tail=50
```

### Step 5 — Specific app (optional, if $ARGUMENTS provided)

```bash
# Pod status
kubectl get pods -n apps -l app=<name>

# Recent events
kubectl describe rollout <name> -n apps

# Live pod logs
kubectl logs -n apps -l app=<name> --tail=50

# Rollout status (blue-green state)
kubectl argo rollouts get rollout <name> -n apps
```

## Common failure patterns

| Symptom | Likely cause | Fix |
|---|---|---|
| App `OutOfSync` | New file not in `kustomization.yaml` | Add file and push |
| App `Degraded` | Pod CrashLoopBackOff | Check `kubectl logs` |
| Ingress 502 | Pod not ready / wrong service name | Check service selector |
| OTEL init container pending | npm download slow on first node schedule | Wait 60 s, normal behaviour |
| Envoy port changed | Cluster was recreated | Run `make urls` |
| Grafana datasource error | Loki/Tempo pod not ready yet | Wait for full sync, check pods in `monitoring` ns |
