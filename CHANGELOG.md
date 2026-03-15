# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2026-03-15

### ⚠️ Breaking Changes

- Refactored application repository structure under applications:
  - Added applications/apps for Argo CD Application manifests
  - Renamed applications/samples to applications/microservices
  - Renamed demo-nginx application to microservice-a
  - Added a second sample app, microservice-b
- Updated Argo CD and Kustomize paths to the new directory layout.
- Replaced legacy demo host and ingress naming with microservice-specific hosts:
  - microservice-a.127.0.0.1.nip.io
  - microservice-b.127.0.0.1.nip.io

### ✨ New Features

- Added microservice-b with its own Rollout, Service, Ingress, and Argo CD Application.
- Updated helper commands and ingress test script to include both microservices.

### 🧭 Migration Notes

- If you referenced old paths like applications/samples/demo-nginx-app, update automation to:
  - applications/microservices/microservice-a
  - applications/microservices/microservice-b
- If you used demo.127.0.0.1.nip.io, switch to the new microservice hostnames.

---

## [1.1.0] - 2026-03-08

### 🎉 Version 1.1.0 - Sealed Secrets Support

#### ✨ New Features

- **Sealed Secrets Integration**: Add secure secret management with Bitnami Sealed Secrets
  - Automatic controller deployment via Helm (v2.16.2)
  - Encrypted secrets stored safely in Git
  - Sync-wave 0 for early deployment in bootstrap sequence

#### 📖 Documentation

- Comprehensive Sealed Secrets README with:
  - Installation and usage guide (cluster and certificate-based approaches)
  - Backup and key rotation procedures
  - Troubleshooting guide for common issues
  - Scope types (strict, namespace-wide, cluster-wide)

#### 🛠 Infrastructure

- New sealed-secrets directory with:
  - `sealed-secrets-application.yaml` - ArgoCD Application manifest
  - `kustomization.yaml` - Kustomize configuration
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
