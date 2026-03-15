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

### 🌐 Quick Access to Applications

```bash
# Get all application URLs instantly
make urls
```

**Output:**
```
📱 Application URLs (via LoadBalancer):

       🚀 Microservice A: http://microservice-a.127.0.0.1.nip.io:63404
       🚀 Microservice B: http://microservice-b.127.0.0.1.nip.io:63404
   📊 Grafana:     http://grafana.127.0.0.1.nip.io:63404  (admin/admin)
   📈 Prometheus:  http://prometheus.127.0.0.1.nip.io:63404
   🔄 Argo CD:     http://argocd.127.0.0.1.nip.io:63404
```

**No DNS configuration needed!** The apps use `*.127.0.0.1.nip.io` domains which work automatically without editing `/etc/hosts`.

> 💡 **Want different access methods?** See [docs/ACCESSING-APPS.md](docs/ACCESSING-APPS.md) for 5 complete approaches including port-forward, NodePort with fixed ports 80/443, and more.

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
         ├─ microservice-a
         └─ microservice-b
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
| **Microservice A/B** | Sample applications | latest |

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
│   ├── apps/                    # Argo CD Application resources
│   │   ├── microservice-a-application.yaml
│   │   └── microservice-b-application.yaml
│   └── microservices/
│       ├── microservice-a/      # Example nginx deployment A
│       └── microservice-b/      # Example nginx deployment B
│
├── docs/
│   └── ACCESSING-APPS.md        # Comprehensive guide: 5 ways to access apps
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

# Get all application URLs (no /etc/hosts needed!)
make urls

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

### Quick Access (Easiest Method) ✅

**Get all URLs with one command:**

```bash
make urls
```

This shows URLs for all services using **nip.io DNS** (no `/etc/hosts` editing required!):

```
📱 Application URLs (via LoadBalancer):

       🚀 Microservice A: http://microservice-a.127.0.0.1.nip.io:63404
       🚀 Microservice B: http://microservice-b.127.0.0.1.nip.io:63404
   📊 Grafana:     http://grafana.127.0.0.1.nip.io:63404  (admin/admin)
   📈 Prometheus:  http://prometheus.127.0.0.1.nip.io:63404
   🔄 Argo CD:     http://argocd.127.0.0.1.nip.io:63404
```

**Just copy/paste the URLs into your browser!** 🎉

> **Note:** The port number changes when you recreate the cluster. Just run `make urls` again to get the current URLs.

### 5 Different Ways to Access Your Apps

**Need a different access method?** We've got you covered with 5 complete options:

📖 **See [docs/ACCESSING-APPS.md](docs/ACCESSING-APPS.md)** for the comprehensive guide:

1. **nip.io DNS** (✅ current) - Already configured! No setup needed, works immediately
2. **kubectl port-forward** (🚀 quick testing) - Standard ports (3000, 9090, 8080), no config changes
3. **NodePort + fixed ports** (🎯 production-like) - Use ports 80/443, predictable and stable
4. **hostPort + DaemonSet** (🏃 advanced) - Direct node binding, high availability
5. **Host header with curl** (🔄 automation) - Test ingress routing without browser

**Comparison:**

| Method | Ports | Setup | Ingress Testing | Best For |
|--------|-------|-------|-----------------|----------|
| nip.io | Random | None | ✅ Yes | Daily use (current) |
| port-forward | Standard | None | ❌ No | Quick service testing |
| NodePort | 80/443 | Cluster rebuild | ✅ Yes | Production-like setup |
| hostPort | 80/443 | Cluster rebuild | ✅ Yes | Advanced scenarios |
| Host header | Random | None | ✅ Yes | CI/CD & automation |

### Quick Port-Forward Examples

For quick testing without ingress:

```bash
# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Access: http://localhost:3000 (admin/admin)

# Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Access: http://localhost:9090

# Argo CD
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Access: https://localhost:8080 (admin/<password from make argocd-password>)

# Microservice A
kubectl port-forward -n apps svc/service-a 8081:80
# Access: http://localhost:8081

# Microservice B
kubectl port-forward -n apps svc/service-b 8082:80
# Access: http://localhost:8082
```

**💡 Tip:** For production-like environments with ports 80/443, see the NodePort configuration in [docs/ACCESSING-APPS.md](docs/ACCESSING-APPS.md#option-3-nodeport--fixed-kind-port-mappings-).

## 🧪 Testing LoadBalancer & Ingress

This setup uses **cloud-provider-kind** to emulate cloud LoadBalancers (AWS ELB, GCP LB, Azure LB), providing a **production-like environment** locally.

### Verify LoadBalancer Service

```bash
# Check HAProxy ingress controller has an EXTERNAL-IP
kubectl get svc -n networking haproxy-kubernetes-ingress

# Output should show:
# NAME                          TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
# haproxy-kubernetes-ingress    LoadBalancer   10.96.104.30   172.18.0.7    80:31505/TCP,443:30409/TCP
```

**✅ If you see an EXTERNAL-IP** (e.g., `172.18.0.7`), LoadBalancer is working!

**❌ If stuck on `<pending>`**, check cloud-provider-kind:

```bash
docker ps | grep cloud-provider
# Should show: kind-cloud-provider container running

# Check logs
docker logs kind-cloud-provider

# Restart if needed
make cloud-provider-restart
```

### Test Ingress Rules with curl

Verify ingress routing works correctly:

```bash
# Get the envoy proxy port (LoadBalancer frontend)
ENVOY_PORT=$(docker port $(docker ps -q --filter "ancestor=envoyproxy/envoy:v1.33.2") 80/tcp | cut -d':' -f2)

# Test demo app ingress
curl -v http://demo.127.0.0.1.nip.io:${ENVOY_PORT}
# Should return: nginx welcome page

# Test Grafana ingress
curl -v http://grafana.127.0.0.1.nip.io:${ENVOY_PORT}
# Should return: Grafana login page (302 redirect)

# Test Prometheus ingress
curl -v http://prometheus.127.0.0.1.nip.io:${ENVOY_PORT}
# Should return: Prometheus UI HTML

# Test with Host header (alternative - for automation/CI)
curl -H "Host: demo.127.0.0.1.nip.io" http://localhost:${ENVOY_PORT}
# Should return: nginx welcome page
```

### Verify Ingress Resources

```bash
# List all ingress resources
kubectl get ingress --all-namespaces

# Example output:
# NAMESPACE    NAME                  CLASS      HOSTS                           ADDRESS      PORTS
# apps         ingress-a             haproxy    demo.127.0.0.1.nip.io          172.18.0.7   80
# monitoring   ingress-monitoring    haproxy    grafana.127.0.0.1.nip.io       172.18.0.7   80
#                                               prometheus.127.0.0.1.nip.io

# Detailed view of specific ingress
kubectl describe ingress -n apps ingress-a
```

### Understanding the LoadBalancer Flow

The complete request path: **Browser → Envoy → HAProxy → Service → Pod**

```
┌─────────────┐
│   Browser   │
│  (your Mac) │
└──────┬──────┘
       │ http://demo.127.0.0.1.nip.io:63404
       ▼
┌─────────────────────────────────────────┐
│  Envoy Proxy (cloud-provider-kind)      │
│  Docker container on host               │
│  Maps: 0.0.0.0:63404 → 172.18.0.7:80   │
└──────┬──────────────────────────────────┘
       │ Forward to LoadBalancer IP
       ▼
┌─────────────────────────────────────────┐
│  HAProxy Ingress Controller             │
│  LoadBalancer: 172.18.0.7:80           │
│  (inside Kind cluster)                  │
└──────┬──────────────────────────────────┘
       │ Route based on Host header
       ▼
┌─────────────────────────────────────────┐
│  Backend Service (ClusterIP)            │
│  service-a, monitoring-grafana, etc.    │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  Application Pods                       │
│  nginx, grafana, prometheus, etc.       │
└─────────────────────────────────────────┘
```

**This mimics cloud environments** where:
- **Envoy** = Cloud provider's edge router/load balancer
- **HAProxy** = Application load balancer (ALB/NLB)
- **Service** = Kubernetes service abstraction
- **Pods** = Your application containers

### Verify Complete Request Flow

```bash
# 1. Check envoy proxy is routing to HAProxy LoadBalancer
docker port $(docker ps -q --filter "ancestor=envoyproxy/envoy:v1.33.2")

# 2. Verify HAProxy ingress controller pods are running
kubectl get pods -n networking

# 3. Check backend service endpoints
kubectl get endpoints -n apps service-a
kubectl get endpoints -n monitoring monitoring-grafana

# 4. Test end-to-end connectivity
curl -I http://demo.127.0.0.1.nip.io:${ENVOY_PORT}
# Should return: HTTP/1.1 200 OK

# 5. Verify ingress logs (optional)
kubectl logs -n networking -l app.kubernetes.io/name=kubernetes-ingress --tail=50
```

### Quick Test Script

The repository includes `scripts/test-ingress.sh` to verify all ingresses:

```bash
./scripts/test-ingress.sh
```

This tests all ingress routes and reports HTTP status codes (200 = success, 302 = redirect to login).

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