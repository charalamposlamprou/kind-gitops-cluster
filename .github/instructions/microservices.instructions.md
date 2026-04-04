---
description: "Use when creating, editing, or reviewing microservice manifests under applications/. Covers Rollout spec, blue-green strategy, OTEL auto-instrumentation env vars, kustomization structure, and Argo CD Application fields."
applyTo: "applications/**"
---

# Microservice Manifests

## Required files per microservice

Every service under `applications/microservices/<name>/` must contain exactly these files:

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Entry point; sets namespace + labels |
| `deployment.yaml` | `kind: Rollout` — blue-green strategy |
| `service.yaml` | Active ClusterIP service |
| `preview-service.yaml` | Preview ClusterIP service (blue-green) |
| `configmap.yaml` | Application code (`app.js`) mounted as a volume |
| `ingress.yaml` | HAProxy ingress with nip.io hostname |

The Argo CD Application YAML lives in `applications/apps/<name>-application.yaml` and must be referenced in `applications/kustomization.yaml`.

## Rollout spec (`deployment.yaml`)

Use `kind: Rollout`, **not** `kind: Deployment`. The API group is `argoproj.io/v1alpha1`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: <name>
  namespace: apps
spec:
  replicas: 2
  strategy:
    blueGreen:
      activeService: service-<name>
      previewService: service-<name>-preview
  selector:
    matchLabels:
      app: <name>
      app.kubernetes.io/name: <name>
      app.kubernetes.io/part-of: microservices
  template:
    metadata:
      labels:
        app: <name>
        app.kubernetes.io/name: <name>
        app.kubernetes.io/part-of: microservices
    spec:
      initContainers:
        - name: install-otel
          image: node:20-alpine
          command:
            - npm
            - install
            - --prefix
            - /otel
            - --no-fund
            - --no-audit
            - --omit=dev
            - "@opentelemetry/auto-instrumentations-node"
          volumeMounts:
            - name: otel-modules
              mountPath: /otel
      containers:
        - name: node-app
          image: node:20-alpine
          workingDir: /app
          command: ["node", "app.js"]
          ports:
            - name: http
              containerPort: 80
          env:
            # --- OTEL (all required, do not omit) ---
            - name: OTEL_SERVICE_NAME
              value: <name>
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: http://otel-collector.monitoring.svc.cluster.local:4318
            - name: OTEL_EXPORTER_OTLP_PROTOCOL
              value: http/protobuf
            - name: NODE_PATH
              value: /otel/node_modules
            - name: NODE_OPTIONS
              value: --require @opentelemetry/auto-instrumentations-node/register
            - name: OTEL_NODE_RESOURCE_DETECTORS
              value: env,host,os,process,container
            - name: OTEL_METRICS_EXPORTER
              value: none
            - name: OTEL_LOGS_EXPORTER
              value: none
          volumeMounts:
            - name: app-config
              mountPath: /app/app.js
              subPath: app.js
            - name: otel-modules
              mountPath: /otel
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 400m
              memory: 256Mi
      volumes:
        - name: app-config
          configMap:
            name: <name>-app
            items:
              - key: app.js
                path: app.js
        - name: otel-modules
          emptyDir: {}
```

### OTEL env var checklist

- [ ] `OTEL_SERVICE_NAME` — matches the microservice name
- [ ] `OTEL_EXPORTER_OTLP_ENDPOINT` — `http://otel-collector.monitoring.svc.cluster.local:4318`
- [ ] `OTEL_EXPORTER_OTLP_PROTOCOL` — `http/protobuf`
- [ ] `NODE_PATH` — `/otel/node_modules`
- [ ] `NODE_OPTIONS` — `--require @opentelemetry/auto-instrumentations-node/register`
- [ ] `OTEL_NODE_RESOURCE_DETECTORS` — `env,host,os,process,container`
- [ ] `OTEL_METRICS_EXPORTER` — `none`
- [ ] `OTEL_LOGS_EXPORTER` — `none`

Do **not** add manual span creation — the SDK instruments Node.js `http` and `undici`/`fetch` automatically and propagates W3C `traceparent` headers.

## kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: apps

resources:
  - deployment.yaml
  - service.yaml
  - preview-service.yaml
  - configmap.yaml
  - ingress.yaml

labels:
  - includeSelectors: true
    pairs:
      app.kubernetes.io/name: <name>
      app.kubernetes.io/part-of: microservices
```

## Ingress (`ingress.yaml`)

```yaml
ingressClassName: haproxy
# host: <name>.127.0.0.1.nip.io
```

Always use `ingressClassName: haproxy`. Host must follow the `<name>.127.0.0.1.nip.io` pattern.

## Argo CD Application (`applications/apps/<name>-application.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <name>
  namespace: argocd
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: apps
  source:
    repoURL: https://github.com/charalamposlamprou/kind-gitops-cluster.git
    targetRevision: HEAD
    path: applications/microservices/<name>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- Always set `targetRevision: HEAD` for new services (not `test-1234`).
- After creating the Application YAML, add it to `applications/kustomization.yaml` under `resources:`.
