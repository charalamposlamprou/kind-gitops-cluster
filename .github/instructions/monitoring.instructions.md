---
description: "Use when adding or editing Grafana dashboards, Prometheus rules, or observability configuration under infrastructure/monitoring/. Covers ConfigMap dashboard provisioning, datasource UIDs, and alerting conventions."
applyTo: "infrastructure/monitoring/**"
---

# Monitoring & Observability

## Stack overview

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| Prometheus | `monitoring` | Metrics scrape + storage (kube-prometheus-stack) |
| Grafana | `monitoring` | Dashboards — release name `monitoring`, service `monitoring-grafana` |
| Loki | `monitoring` | Log aggregation |
| Tempo | `monitoring` | Distributed traces |
| OTel Collector | `monitoring` | DaemonSet — receives OTLP from pods, routes to Loki/Tempo/Prometheus |

## Grafana dashboards

Dashboards are provisioned via ConfigMaps picked up by the Grafana sidecar. All dashboards live in `infrastructure/monitoring/dashboards/` and must be listed in `infrastructure/monitoring/dashboards/kustomization.yaml`.

### ConfigMap structure

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <dashboard-slug>-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"          # required — triggers sidecar pickup
  annotations:
    grafana_folder: "Microservices" # Grafana folder name (use "Microservices" for app dashboards)
data:
  <dashboard-slug>.json: |
    {
      "title": "...",
      "uid": "<dashboard-slug>",    # unique, stable, kebab-case
      "schemaVersion": 39,
      ...
    }
```

### Datasource UIDs (use these exact values in panels)

| Datasource | UID |
|-----------|-----|
| Prometheus | `prometheus` (default datasource) |
| Loki | `loki` |
| Tempo | `tempo` |

Always reference datasources by UID, not by name, to avoid breakage on rename.

### Dashboard JSON conventions

- `uid` — kebab-case, unique across all dashboards, stable across edits (never auto-generate)
- `schemaVersion` — keep at `39`
- `refresh` — `"30s"` for live dashboards, `""` (empty) for trace/log exploration panels
- Template variable `DS_PROMETHEUS` type `datasource` with `hide: 2` (hidden, used for portability)
- Folder: always `grafana_folder: "Microservices"` for application-level dashboards

### Adding a new dashboard

1. Export JSON from Grafana UI (Dashboard → Share → Export → JSON).
2. Create `infrastructure/monitoring/dashboards/<name>-dashboard.yaml` following the ConfigMap template above.
3. Add it to `infrastructure/monitoring/dashboards/kustomization.yaml`.
4. Argo CD auto-syncs; the Grafana sidecar hot-reloads the dashboard within ~30 s.

## Prometheus alerting rules

Not yet implemented. When added, use `PrometheusRule` CRDs in `infrastructure/monitoring/` and register in `kustomization.yaml`. The CRDs are already installed by `prometheus-crds-application.yaml`.

## OTel Collector

Configured via Helm values in `infrastructure/monitoring/otel-collector-application.yaml`. Routes:
- Traces → Tempo (OTLP gRPC)
- Metrics → Prometheus (OTLP)
- Logs → Loki (via loki exporter with `service_name` resource label)

The collector endpoint used by microservices: `http://otel-collector.monitoring.svc.cluster.local:4318` (OTLP HTTP).

## Datasource cross-links

Grafana is pre-configured with:
- Traces → Logs: Tempo links to Loki using `service_name` label
- Traces → Metrics: Tempo links to Prometheus using `service_name` label

Preserve these `tracesToLogsV2` and `tracesToMetrics` blocks in `kube-prometheus-stack-application.yaml` when updating Helm values.
