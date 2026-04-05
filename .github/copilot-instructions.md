# Project Guidelines

## Architecture

GitOps-driven local Kubernetes platform using **Argo CD App-of-Apps** pattern:

```
root-app (bootstrap/root-application.yaml)
├── infra-app → infrastructure/        # HAProxy, monitoring, sealed-secrets, argo-rollouts
└── apps-app  → applications/          # Microservice Argo Applications
    ├── microservice-a → applications/microservices/microservice-a/
    └── microservice-b → applications/microservices/microservice-b/
```

- All Argo CD Applications use `syncPolicy.automated` with `prune: true` and `selfHeal: true`.
- `bootstrap/root-application.yaml` contains `__REPO_URL__` and `__TARGET_REVISION__` placeholders — rendered by `make bootstrap` via `sed` substitution. Never apply it raw with `kubectl`.
- `cloud-provider-kind` (Envoy LoadBalancer emulation) runs as a Docker Compose service on the host — it is **not** managed by Argo CD. Manage it with `make cloud-provider-up/down`.

## Build and Test Commands

```bash
make cluster-up          # Create kind cluster + start cloud-provider-kind
make bootstrap           # Install Argo CD and apply root App-of-Apps
make apps-install        # Trigger hard refresh on root-app; show app status
make urls                # Print all service URLs (nip.io DNS + current envoy port)
make argocd-password     # Get Argo CD admin password
make argocd-status       # kubectl get applications -n argocd
make test-ingress        # Smoke-test all ingress routes via LoadBalancer
make test-otel           # Validate traces→Tempo, metrics→Prometheus, logs→Loki pipeline
make cluster-down        # Tear down cluster + stop cloud-provider-kind
```

## Conventions

### Microservice structure
Each microservice under `applications/microservices/<name>/` must have:
- `kustomization.yaml` — namespace `apps`, common labels (`app.kubernetes.io/name`, `app.kubernetes.io/part-of`)
- `deployment.yaml` — **`kind: Rollout`** (Argo Rollouts) with **blue-green strategy**, not a standard `Deployment`
- `service.yaml` + `preview-service.yaml` — ClusterIP services for active and preview traffic
- `configmap.yaml` — application code mounted into the container (not a separate image tag)
- `ingress.yaml` — `ingressClassName: haproxy`, host pattern `<name>.127.0.0.1.nip.io`

Each microservice Argo CD Application lives in `applications/apps/<name>-application.yaml` and must be added to `applications/kustomization.yaml`.

### OpenTelemetry auto-instrumentation
Every microservice Rollout includes:
- An `install-otel` init container that installs `@opentelemetry/auto-instrumentations-node` into an `emptyDir` volume at `/otel`
- `NODE_PATH=/otel/node_modules` + `NODE_OPTIONS=--require @opentelemetry/auto-instrumentations-node/register`
- `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf` pointing to `otel-collector.monitoring:4318`

Do not add manual span instrumentation — the SDK handles HTTP in/out and W3C `traceparent` propagation automatically.

### Secrets
Use **Sealed Secrets** for anything sensitive committed to Git. See [infrastructure/sealed-secrets/README.md](../infrastructure/sealed-secrets/README.md) for `kubeseal` usage.

### Ingress class
Always use `ingressClassName: haproxy`. The monitoring and Argo CD ingresses follow the same pattern in `infrastructure/monitoring/ingress-monitoring.yaml` and `infrastructure/argocd/base/ingress.yaml`.

## Pitfalls

- **`targetRevision`**: Microservice Applications currently point to branch `test-1234`, not `HEAD`. When creating new applications, set `targetRevision: HEAD` unless intentionally targeting a feature branch.
- **Port changes**: The envoy LoadBalancer port changes every time the cluster is recreated. Always run `make urls` to get current URLs — never hardcode the port.
- **Pod startup latency**: The OTEL init container downloads npm packages on first schedule per node (~30–60 s). This is expected; subsequent pod starts on the same node are faster.
- **Bootstrap is not idempotent on first run**: Run `make cluster-up` before `make bootstrap`. Argo CD must be healthy before applying the root app.

## Git Workflow

- Branch from `main`: `feature/<desc>`, `fix/<desc>`, `chore/<desc>`
- All changes via Pull Request — never push directly to `main`
- Use conventional commits: `feat:`, `fix:`, `chore:`, `perf:` — the release workflow auto-bumps semver on merge
- CI runs `kubectl kustomize` + `kubeconform` on every PR; it must pass before merging

## Key Reference Docs

- Access methods (nip.io, port-forward, NodePort): [docs/ACCESSING-APPS.md](../docs/ACCESSING-APPS.md)
- Sealed Secrets usage: [infrastructure/sealed-secrets/README.md](../infrastructure/sealed-secrets/README.md)
- cloud-provider-kind setup: [infrastructure/cloud-provider/README.md](../infrastructure/cloud-provider/README.md)

## Instruction files (auto-loaded by Copilot)

| File | Applies to |
|------|-----------|
| [general.instructions.md](.github/instructions/general.instructions.md) | `**` (all files) |
| [microservices.instructions.md](.github/instructions/microservices.instructions.md) | `applications/**` |
| [infrastructure.instructions.md](.github/instructions/infrastructure.instructions.md) | `infrastructure/**` |
| [monitoring.instructions.md](.github/instructions/monitoring.instructions.md) | `infrastructure/monitoring/**` |
| [cluster.instructions.md](.github/instructions/cluster.instructions.md) | `infrastructure/cluster/**` |
| [secrets.instructions.md](.github/instructions/secrets.instructions.md) | `**/*sealed*.yaml` + on-demand |
| [ci.instructions.md](.github/instructions/ci.instructions.md) | `.github/workflows/**` + `CHANGELOG.md` |

## Prompts (slash commands)

### Spec-Driven Development (SDD)

Use these three commands in order for every new task:

| Command | What it does |
|---------|-------------|
| `/specs DEVOPS-XXXX <description>` | Creates branch `DEVOPS-XXXX` from `main` and generates `_specs/DEVOPS-XXXX.md` from your description |
| `/plan DEVOPS-XXXX` | Reads the spec and generates `_plans/DEVOPS-XXXX.md` with all files, steps, and validation |
| `/implement DEVOPS-XXXX` | Executes the plan step by step; stages changes for engineer review |

**Rule:** never run `/implement` without an approved plan in `_plans/`.

### Infrastructure & Microservices

| Command | What it does |
|---------|-------------|
| `/add-microservice <name>` | Scaffolds all 6 microservice files + Argo CD Application |
| `/add-infra-component <name>` | Scaffolds Argo CD Application + kustomization for a Helm chart |
| `/add-dashboard <slug>` | Scaffolds a Grafana dashboard ConfigMap from JSON input |
| `/validate-cluster [name]` | End-to-end health check: Argo CD status, ingress, OTel pipeline |
