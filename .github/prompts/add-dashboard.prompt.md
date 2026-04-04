---
description: "Scaffold a new Grafana dashboard ConfigMap under infrastructure/monitoring/dashboards/ from a dashboard name and JSON input."
argument-hint: "Slug for the dashboard (e.g. microservice-latency)"
agent: "agent"
---

Scaffold a new Grafana dashboard named **$ARGUMENTS** in this GitOps cluster.

Follow [.github/instructions/monitoring.instructions.md](../instructions/monitoring.instructions.md) for all conventions. Use an existing dashboard as the canonical reference:

- [infrastructure/monitoring/dashboards/microservices-metrics-dashboard.yaml](../../infrastructure/monitoring/dashboards/microservices-metrics-dashboard.yaml)
- [infrastructure/monitoring/dashboards/kustomization.yaml](../../infrastructure/monitoring/dashboards/kustomization.yaml)

## Steps

1. **Ask the user** for the dashboard JSON if not already provided in the conversation.
   - If the user pastes raw Grafana export JSON, use it as the `data` value below.
   - If no JSON is provided, generate a minimal working dashboard with a single "No data" text panel as a placeholder.

2. Before writing the JSON, validate and enforce these conventions:
   - `uid` — set to `$ARGUMENTS` (kebab-case, stable)
   - `schemaVersion` — must be `39`
   - Datasource references must use UIDs, not names:
     - Prometheus → `{ "type": "prometheus", "uid": "prometheus" }` or template var `${DS_PROMETHEUS}`
     - Loki → `{ "type": "loki", "uid": "loki" }`
     - Tempo → `{ "type": "tempo", "uid": "tempo" }`
   - Add `DS_PROMETHEUS` hidden template variable if any panel uses Prometheus (type `datasource`, `hide: 2`)
   - `refresh: "30s"` for metric dashboards; `""` for trace/log exploration

3. Create `infrastructure/monitoring/dashboards/$ARGUMENTS-dashboard.yaml`:

   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: $ARGUMENTS-dashboard
     namespace: monitoring
     labels:
       grafana_dashboard: "1"
     annotations:
       grafana_folder: "Microservices"
   data:
     $ARGUMENTS.json: |
       <dashboard JSON here>
   ```

4. Register in `infrastructure/monitoring/dashboards/kustomization.yaml`
   - Add `- $ARGUMENTS-dashboard.yaml` to the `resources:` list

After creating the file, confirm what was created and remind the user that:
- Argo CD syncs the ConfigMap automatically after push
- The Grafana sidecar hot-reloads dashboards within ~30 s — no Grafana restart needed
