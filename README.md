# Local Kubernetes GitOps Platform

A **production-ready local Kubernetes environment** using GitOps principles with Argo CD, complete with ingress controller, monitoring stack, and LoadBalancer support.

## 🎯 What Is This?

This repository provides a **fully declarative, GitOps-driven local Kubernetes setup** that mimics production cloud environments. Everything is managed from Git - just run a few commands and you'll have:

- **Multi-node Kubernetes cluster** (Kind - Kubernetes in Docker)
- **Argo CD** for GitOps continuous deployment
- **HAProxy Ingress Controller** for HTTP/HTTPS routing
- **LoadBalancer support** via cloud-provider-kind (just like AWS/GCP)
- **Prometheus + Grafana** monitoring stack
- **App-of-Apps pattern** for managing infrastructure and applications
- **Sample applications** ready to run

Perfect for local development, testing GitOps workflows, or learning Kubernetes patterns!

## 🚀 Quick Start

### Prerequisites

- **Docker Desktop** or **Podman** (running)
- **kubectl** (Kubernetes CLI)
- **kind** (Kubernetes in Docker) - [Install](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- **GNU Make** (should be pre-installed on macOS/Linux)
- **Git** (to clone this repo)

### One-Time Setup

```bash
# 1. Clone this repository
git clone https://github.com/charalamposlamprou/kind-gitops-cluster.git
cd kind-gitops-cluster

# 2. Create the local Kubernetes cluster
make cluster-up

# 3. Install Argo CD and bootstrap GitOps
make bootstrap

# 4. Deploy all applications
make apps-install
```

**That's it!** Argo CD will now manage everything from Git.

### Verify Installation

```bash
# Check all applications are synced and healthy
kubectl get applications -n argocd

# You should see:
# apps-app           Synced   Healthy
# infra-app          Synced   Healthy
# ingress-haproxy    Synced   Healthy
# monitoring-stack   Synced   Healthy
# prometheus-crds    Synced   Healthy
# root-app           Synced   Healthy
```

## 🏗️ Architecture

### GitOps App-of-Apps Pattern

This repository uses Argo CD's **App-of-Apps pattern** - a hierarchical structure where one root application creates and manages child applications:

```
root-app (bootstrap/root-application.yaml)
  │
  ├─ infra-app → infrastructure/
  │   ├─ prometheus-crds (CRDs for monitoring)
  │   ├─ ingress-haproxy (HAProxy ingress controller)
  │   └─ monitoring-stack (Prometheus + Grafana)
  │
  └─ apps-app → applications/
      └─ demo-nginx-app (sample application)
```

**Benefits:**
- Add new apps by just creating a directory - Argo CD discovers them automatically
- Infrastructure is deployed before applications
- Everything is version-controlled and declarative
- Easy rollback via Git revert

### Components Included

| Component | Purpose | Version |
|-----------|---------|---------|
| **Kind** | Local Kubernetes cluster | v1.33.1 |
| **Argo CD** | GitOps continuous deployment | v2.13.2 |
| **HAProxy Ingress** | HTTP/HTTPS routing | v3.1.9 (chart 1.46.0) |
| **cloud-provider-kind** | LoadBalancer emulation | v0.7.0 |
| **kube-prometheus-stack** | Monitoring (Prometheus + Grafana) | v70.0.0 |
| **Demo Nginx App** | Sample application | latest |

## 📂 Repository Structure

```
├── bootstrap/                    # App-of-Apps entry point
│   ├── root-application.yaml    # Root app (creates infra-app + apps-app)
│   └── apps/
│       ├── infrastructure.yaml  # Child app pointing to infrastructure/
│       └── applications.yaml    # Child app pointing to applications/
│
├── infrastructure/               # Infrastructure components
│   ├── cluster/
│   │   └── kind-config.yaml     # Kind cluster configuration (4 nodes)
│   ├── argocd/
│   │   ├── base/                # Argo CD base manifests
│   │   └── overlays/local/      # Local environment overlay
│   ├── ingress/
│   │   └── haproxy-application.yaml  # HAProxy ingress Argo app
│   ├── monitoring/
│   │   ├── prometheus-crds/     # Prometheus Operator CRDs
│   │   ├── prometheus-crds-application.yaml
│   │   ├── kube-prometheus-stack-application.yaml
│   │   └── ingress-monitoring.yaml   # Grafana/Prometheus ingress
│   └── cloud-provider/
│       └── compose.yaml         # cloud-provider-kind (host component)
│
├── applications/                 # Your applications go here
│   └── samples/
│       └── demo-nginx-app/      # Example nginx deployment
│
├── Makefile                      # Lifecycle automation
└── README.md                     # This file
```

## 🎮 Available Commands

### Cluster Management

```bash
# Create/start the local Kubernetes cluster
make cluster-up

# Stop and delete the cluster
make cluster-down
```

### GitOps Operations

```bash
# Bootstrap Argo CD (first-time setup)
make bootstrap

# Deploy/sync all applications
make apps-install

# Get Argo CD admin password
make argocd-password

# Check Argo CD application status
make argocd-status
```

### Cloud Provider (LoadBalancer Support)

```bash
# Start cloud-provider-kind
make cloud-provider-up

# Stop cloud-provider-kind
make cloud-provider-down

# Restart and wait for readiness
make cloud-provider-restart
```

## 🌐 Accessing Services

### Argo CD Web UI

```bash
# Get the dynamically assigned port
kubectl get svc argocd-server -n argocd

# Or use port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: (run `make argocd-password`)
```

### Grafana Dashboard

```bash
# Access via LoadBalancer ingress (if DNS configured)
# http://grafana.127.0.0.1.nip.io

# Or use port-forward
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

# Open browser: http://localhost:3000
# Username: admin
# Password: admin
```

### Prometheus

```bash
# Access via LoadBalancer ingress
# http://prometheus.127.0.0.1.nip.io

# Or use port-forward
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090

# Open browser: http://localhost:9090
```

### Demo Nginx App

```bash
# Access via LoadBalancer ingress
# http://demo.127.0.0.1.nip.io

# Or check the service
kubectl get svc -n apps
```

## ➕ Adding New Applications

Adding a new application is **simple** - Argo CD will discover it automatically!

### 1. Create Application Directory

```bash
mkdir -p applications/my-app
```

### 2. Add Kubernetes Manifests

Create `applications/my-app/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
```

Add your manifests (namespace.yaml, deployment.yaml, etc.)

### 3. Commit and Push

```bash
git add applications/my-app/
git commit -m "Add my-app"
git push
```

### 4. Sync (or wait for auto-sync)

```bash
make apps-install
```

**That's it!** Argo CD automatically discovers the new directory and creates an application for it.

## 🔧 Troubleshooting

### Cluster won't start

```bash
# Make sure Docker/Podman is running
docker info

# Delete and recreate cluster
make cluster-down
make cluster-up
```

### Applications stuck in "Progressing"

```bash
# Check detailed status
kubectl get application <app-name> -n argocd -o yaml

# Force refresh
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

### LoadBalancer services show "Pending"

```bash
# Check cloud-provider-kind is running
docker ps | grep cloud-provider

# Restart cloud provider
make cloud-provider-restart
```

### Can't access Argo CD UI

```bash
# Get admin password
make argocd-password

# Forward port manually
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access: https://localhost:8080 (accept self-signed cert)
```

## 🎓 Learning Resources

**GitOps & Argo CD:**
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

**Kubernetes:**
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kustomize](https://kustomize.io/)

**Monitoring:**
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

## 📝 Technical Details

### Why App-of-Apps?

The App-of-Apps pattern provides:
- **Declarative hierarchy** - Applications create other applications
- **Separation of concerns** - Infrastructure vs workloads
- **Automatic discovery** - Add a directory, get an app
- **Dependency ordering** - Via sync waves (-1 for CRDs, 0 for apps)

### Bootstrap Process

1. **`make cluster-up`** creates a 4-node Kind cluster with proper port mappings
2. **`make bootstrap`** applies Argo CD via Kustomize (imperative, one-time only)
3. Root application is created pointing to `bootstrap/apps/`
4. Root app syncs and creates `infra-app` and `apps-app`
5. **`infra-app`** scans `infrastructure/` and creates child apps (CRDs, ingress, monitoring)
6. **`apps-app`** scans `applications/` and creates application deployments
7. All subsequent changes are GitOps - commit to Git, Argo CD syncs automatically

### Why Separate CRD Application?

Prometheus CRDs from Helm chart v70.0.0 have oversized annotations (>262KB limit). We:
- Fetch official CRDs from prometheus-operator GitHub releases (minimal annotations)
- Use sync wave `-1` to install CRDs before monitoring-stack (wave `0`)
- Enable `skipCrds: true` in Helm chart to avoid annotation overflow

### Idempotency

All `make` targets are **safe to re-run**:
- `cluster-up` checks if cluster exists before creating
- `bootstrap` uses `kubectl apply` (safe for existing resources)
- `apps-install` triggers refresh (no side effects)

## 🤝 Contributing

Contributions welcome! This is a reference implementation - feel free to fork and customize for your needs.

## 📄 License

MIT License - use freely!