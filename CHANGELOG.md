# Changelog

All notable changes to this project will be documented in this file.

---

## [2.3.0] - 2026-03-21

### ✨ New Features

- **Grafana Dashboards for Microservices Observability**: Three pre-provisioned dashboards deployed as ConfigMaps, automatically picked up by the Grafana sidecar in kube-prometheus-stack.
  - **Microservices - Metrics** (`microservices-metrics`): Running pod count, container restarts (24h), CPU usage, memory usage, and network I/O — all scoped by a `$service` template variable.
  - **Microservices - Logs** (`microservices-logs`): Log volume bar chart, per-service log panels for microservice-a and microservice-b (using Loki `service_name` label), and a combined log explorer panel.
  - **Microservices - Traces** (`microservices-traces`): Per-service TraceQL trace tables for microservice-a and microservice-b, a combined trace search panel, and a `$min_duration` filter variable — all backed by Tempo.
- Added `infrastructure/monitoring/dashboards/` directory with a dedicated `kustomization.yaml`.
- All dashboards grouped under a **"Microservices"** folder in Grafana via the `grafana_folder` annotation.

### 🛠 Infrastructure

- Updated `infrastructure/monitoring/kustomization.yaml` to include the new `dashboards/` directory.

---

## [2.2.1] - 2026-03-20

### 🩹 Patch Updates

- Fixed trace generator script ingress URL detection to correctly resolve the cluster ingress endpoint.

---

## [2.2.0] - 2026-03-20

### ✨ New Features

- **Node.js Microservices with OTLP Tracing**: Replaced nginx-based microservices with Node.js applications that generate distributed traces manually via OTLP HTTP.
  - `microservice-a` calls `microservice-b` at `/call-b` and propagates `traceparent` headers.
  - Both services export spans to the OTel Collector on port 4318.
  - Healthcheck endpoint at `/healthz` also instrumented with spans.
- Added `scripts/generate-traces.sh` for driving trace traffic through the service chain.
- Added `scripts/test-otel.sh` OTel smoke test for validating the full traces → Tempo pipeline.

---

## [2.1.9] - 2026-03-18

### 🩹 Patch Updates

- Aligned Grafana Tempo datasource `tracesToLogsV2` tag mapping (`service.name` → `service_name`) with the Loki stream labels set by the OTel Collector resource processor.

---

## [2.1.8] - 2026-03-18

### 🩹 Patch Updates

- Fixed OTel Collector Loki exporter labels config: added `resource/loki` processor to insert `loki.resource.labels` attribute mapping (`service.name`, `k8s.namespace.name`, `k8s.pod.name`, `k8s.container.name`) so Loki streams have queryable labels.

---

## [2.1.7] - 2026-03-18

### 🩹 Patch Updates

- Wired OTel Collector service pipelines:
  - Traces pipeline: `otlp` receiver → `otlp/tempo` exporter.
  - Logs pipeline: `otlp` + `filelog` receivers → `loki` exporter.
  - Metrics pipeline: `otlp` receiver → `prometheus` exporter.
- Added Tempo, Loki, and Prometheus exporter configs to the collector values.

---

## [2.1.6] - 2026-03-18

### 🩹 Patch Updates

- Corrected `kube-state-metrics` `selectorOverride` format in kube-prometheus-stack values to use a map instead of a list, resolving ArgoCD app-instance label rewrite mismatch.

---

## [2.1.5] - 2026-03-18

### 🩹 Patch Updates

- Aligned `kube-state-metrics` ServiceMonitor selector with Argo CD label rewrites by adding `release: monitoring` and `app.kubernetes.io/name: kube-state-metrics` to the `selectorOverride`.

---

## [2.1.4] - 2026-03-18

### 🩹 Patch Updates

- Disabled `kubeScheduler` scrape target in kube-prometheus-stack for Kind clusters where the scheduler is not exposed on a scrape-compatible port.

---

## [2.1.3] - 2026-03-18

### 🩹 Patch Updates

- Disabled `kubeControllerManager` and `kubeEtcd` scrape targets in kube-prometheus-stack for Kind clusters where these components are not accessible to Prometheus.

---

## [2.1.2] - 2026-03-18

### 🩹 Patch Updates

- Added OTel Collector smoke test verifying the full OTLP → Tempo traces pipeline.
- Fixed daemonset monitoring wiring: switched from ServiceMonitor to PodMonitor for the OTel Collector daemonset and added `podMonitorSelector: {}` / `podMonitorNamespaceSelector: {}` to the Prometheus spec so PodMonitors are discovered.
- Disabled Loki-stack Grafana datasource sidecar to prevent a duplicate default datasource conflict with the kube-prometheus-stack Grafana instance.

---

## [2.1.1] - 2026-03-17

### 🩹 Patch Updates

- Fixed OpenTelemetry Collector Helm values to match chart schema:
  - Moved service port exposure to `ports.metrics`.
  - Updated ServiceMonitor endpoint from `prometheus` to `metrics`.
- Prevents invalid values rendering and ensures metrics scraping remains configured.

---

## [2.1.0] - 2026-03-17

### ✨ New Features

- **Observability Stack**: Added full observability infrastructure to the monitoring namespace.
  - **OpenTelemetry Collector** (daemonset mode, `otel/opentelemetry-collector-contrib`): receives OTLP gRPC/HTTP traces and logs, enriches with Kubernetes attributes via the `kubernetesAttributes` preset, and collects pod logs via `filelog` receiver.
  - **Loki** (Helm chart): log aggregation backend, receives logs from the OTel Collector.
  - **Tempo** (Helm chart): distributed tracing backend, receives traces via OTLP gRPC from the OTel Collector.
  - Loki and Tempo added as additional datasources in Grafana with `tracesToLogsV2` and `tracesToMetrics` correlation links configured.
- Added `monitoring-namespace.yaml` and updated `kustomization.yaml` for the new resources.
- Added `scripts/test-ingress.sh` for quick ingress smoke testing.

---

## [2.0.1] - 2026-03-15

### 🩹 Patch Updates

- Added Argo Rollouts blue/green preview services for both applications:
  - service-a-preview
  - service-b-preview
- Added per-microservice ConfigMaps with custom index.html content:
  - Microservice-a page
  - Microservice-b page
- Mounted ConfigMap-based index pages into nginx containers.
- Updated each microservice kustomization to include preview service and ConfigMap resources.

---

## [2.0.0] - 2026-03-15

### ⚠️ Breaking Changes

- Refactored application repository structure under `applications/`:
  - Added `applications/apps/` for Argo CD Application manifests.
  - Renamed `applications/samples/` to `applications/microservices/`.
  - Renamed demo-nginx application to `microservice-a`.
  - Added a second sample app, `microservice-b`.
- Updated Argo CD and Kustomize paths to the new directory layout.
- Replaced legacy demo host and ingress naming with microservice-specific hosts:
  - `microservice-a.127.0.0.1.nip.io`
  - `microservice-b.127.0.0.1.nip.io`

### ✨ New Features

- Added `microservice-b` with its own Rollout, Service, Ingress, and Argo CD Application.
- Updated helper commands and ingress test script to include both microservices.

### 🧭 Migration Notes

- If you referenced old paths like `applications/samples/demo-nginx-app`, update to:
  - `applications/microservices/microservice-a`
  - `applications/microservices/microservice-b`
- If you used `demo.127.0.0.1.nip.io`, switch to the new microservice hostnames.

---

## [1.3.2] - 2026-03-14

### 🩹 Patch Updates

- Pinned demo-nginx Argo CD Application `targetRevision` to `HEAD` to ensure consistent syncing from the default branch.

---

## [1.3.1] - 2026-03-14

### 🩹 Patch Updates

- Pinned demo app Argo CD Application `targetRevision` to `test-1234` branch for stable tracking during development.

---

## [1.3.0] - 2026-03-14

### ✨ New Features

- Added dedicated Argo CD Application manifest for the demo app, enabling GitOps-managed deployment lifecycle.

---

## [1.2.0] - 2026-03-14

### ✨ New Features

- **Argo Rollouts Integration**:
  - Deployed Argo Rollouts controller and CRDs via Argo CD application (`infrastructure/argo-rollouts/`).
  - Exposed the Argo Rollouts dashboard via HAProxy ingress at `rollouts.127.0.0.1.nip.io`.
  - Converted the demo nginx `Deployment` to an Argo `Rollout` with a blue/green strategy.
  - Added `activeService` and `previewService` references in the Rollout spec.

---

## [1.1.1] - 2026-03-14

### 🛠 CI/CD

- Added GitHub Actions workflows:
  - **PR validation**: runs `kubeconform` for offline Kubernetes manifest schema validation on every pull request.
  - **Release**: automated tagging and release creation on merge.
- Removed unused `pr-validation` and runtime install steps for a leaner CI pipeline.

---

## [1.1.0] - 2026-03-08

### ✨ New Features

- **Sealed Secrets Integration**: Added secure secret management with Bitnami Sealed Secrets.
  - Automatic controller deployment via Helm (v2.16.2).
  - Encrypted secrets stored safely in Git.
  - Sync-wave 0 for early deployment in bootstrap sequence.

### 📖 Documentation

- Comprehensive Sealed Secrets README with:
  - Installation and usage guide (cluster and certificate-based approaches).
  - Backup and key rotation procedures.
  - Troubleshooting guide for common issues.
  - Scope types (strict, namespace-wide, cluster-wide).

### 🛠 Infrastructure

- New `sealed-secrets/` directory with:
  - `sealed-secrets-application.yaml` — ArgoCD Application manifest.
  - `kustomization.yaml` — Kustomize configuration.

---

## [1.0.0] - 2026-03-06

### 🎉 Initial Stable Release

- **GitOps architecture** with Argo CD + Kustomize:
  - Bootstrap root application (`bootstrap/root-application.yaml`) that manages all infrastructure and application Argo CD apps.
  - Separate `bootstrap/apps/` kustomizations for infrastructure and applications layers.
- **HAProxy Ingress Controller** deployed via Argo CD, exposed via hostPort on the Kind node.
- **Kind cluster configuration** (`infrastructure/cluster/kind-config.yaml`) with hostPort mappings for ports 80 and 443.
- **Argo CD** installed in the `argocd` namespace with ingress at `argocd.127.0.0.1.nip.io`.
- **Prometheus / kube-prometheus-stack** (v70.0.0) with Grafana in the `monitoring` namespace.
  - Prometheus CRDs installed separately to avoid Helm annotation overflow.
- Sample nginx demo application with `Deployment`, `Service`, and `Ingress` managed via GitOps.
- `docs/ACCESSING-APPS.md` with curl and `/etc/hosts` access patterns using `*.127.0.0.1.nip.io`.
  - Full setup via `make bootstrap` and `make apps-install`

#### 📝 What's Unchanged

- All existing infrastructure (ArgoCD, Ingress, Monitoring) remains compatible
- No breaking changes to existing deployments

#### 🚀 Getting Started

Install kubeseal CLI:
```bash
brew install kubeseal  # macOS
# or
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.2/kubeseal-0.27.2-linux-amd64.tar.gz
```

Then follow the [Sealed Secrets README](infrastructure/sealed-secrets/README.md) for usage examples.

#### 🔗 References

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Helm Chart](https://github.com/bitnami-labs/sealed-secrets/tree/main/helm/sealed-secrets)

---

## [1.0.0] - Initial Release

- Initial Kind GitOps cluster setup with ArgoCD
- HAProxy Ingress controller
- Kube Prometheus monitoring stack
