# kind GitOps Cluster (Argo CD + Kustomize)

This repository is refactored to a GitOps-first workflow:
- Argo CD for reconciliation
- Kustomize for manifest composition
- App-of-Apps pattern for infra and apps
- HAProxy ingress + cloud-provider-kind + monitoring stack

Only initial Argo CD bootstrap uses imperative `kubectl apply`. Everything else is reconciled from Git.

## Lifecycle Commands

Required commands are preserved:

```bash
make cluster-up
make cluster-down
make bootstrap GITOPS_REPO_URL=https://github.com/<org>/<repo>.git
make apps-install
```

## Repository Layout

```text
infrastructure/
	cluster/
		kind-config.yaml
	ingress/
		kustomization.yaml
		haproxy-application.yaml
	cloud-provider/
		compose.yaml
		README.md
	monitoring/
		kustomization.yaml
		monitoring-namespace.yaml
		kube-prometheus-stack-application.yaml
		ingress-monitoring.yaml
	argocd/
		base/
			kustomization.yaml
			namespace.yaml
			argocd-cmd-params-cm.yaml
			ingress.yaml
		overlays/
			local/
				kustomization.yaml
	kustomization.yaml

applications/
	kustomization.yaml
	samples/
		demo-nginx-app/
			kustomization.yaml
			namespace.yaml
			deployment.yaml
			service.yaml
			ingress.yaml

bootstrap/
	root-application.yaml
	apps/
		kustomization.yaml
		infrastructure.yaml
		applications.yaml
```

## Bootstrap Flow (Safe + Idempotent)

1. `make cluster-up`
	 - Creates or reuses multi-node kind cluster
	 - Starts `cloud-provider-kind` from declarative compose file
2. `make bootstrap GITOPS_REPO_URL=...`
	 - Installs Argo CD via Kustomize
	 - Waits for `argocd-server`
	 - Applies root App-of-Apps with your repo URL
3. `make apps-install`
	 - Triggers root app refresh and shows Argo CD application status

## Best Practices Used

- Infra and apps are separate top-level trees (`infrastructure/` vs `applications/`)
- Argo CD bootstrap is isolated from steady-state reconciliation
- Root App-of-Apps creates child applications (`bootstrap/apps/`)
- Child infra app points to `infrastructure/` and uses recursive directory sync
- Child app app points to `applications/` and uses automated prune + self-heal
- Make targets are idempotent (safe re-runs)

## Notes

- `cloud-provider-kind` is a host-side component; this repo models it declaratively with `compose.yaml` and lifecycle automation.
- Update hostnames (`*.127.0.0.1.nip.io`) if you prefer different local DNS.
- For external access on macOS, `cloud-provider-kind` handles host port mappings for `LoadBalancer` services.