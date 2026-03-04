CLUSTER_NAME ?= local-k8s-cluster
KIND_CONFIG ?= infrastructure/cluster/kind-config.yaml
ARGOCD_NAMESPACE ?= argocd
ROOT_APP_NAME ?= root-app
ROOT_APP_FILE ?= bootstrap/root-application.yaml
GITOPS_REPO_URL ?= https://github.com/charalamposlamprou/kind-gitops-cluster.git
TARGET_REVISION ?= HEAD
CONTAINER_RUNTIME ?= $(shell if command -v docker >/dev/null 2>&1; then echo docker; elif command -v podman >/dev/null 2>&1; then echo podman; else echo none; fi)
COMPOSE_FILE ?= infrastructure/cloud-provider/compose.yaml

.DEFAULT_GOAL := help

.PHONY: help cluster-up cluster-down bootstrap apps-install cloud-provider-up cloud-provider-down argocd-password argocd-status

help:
	@echo "GitOps lifecycle commands"
	@echo "  make cluster-up      - Create kind cluster + start cloud-provider-kind"
	@echo "  make cluster-down    - Stop cloud-provider-kind + delete cluster"
	@echo "  make bootstrap       - Initial Argo CD bootstrap (only imperative apply)"
	@echo "  make apps-install    - Refresh root App-of-Apps and show app status"

cluster-up:
	@if kind get clusters | grep -qx "$(CLUSTER_NAME)"; then \
		echo "Kind cluster '$(CLUSTER_NAME)' already exists"; \
	else \
		echo "Creating kind cluster '$(CLUSTER_NAME)'"; \
		kind create cluster --name "$(CLUSTER_NAME)" --config "$(KIND_CONFIG)"; \
	fi
	@$(MAKE) cloud-provider-up

cloud-provider-up:
	@if [ "$(CONTAINER_RUNTIME)" = "none" ]; then \
		echo "No container runtime found (docker/podman)"; \
		exit 1; \
	fi
	@if [ "$(CONTAINER_RUNTIME)" = "docker" ]; then \
		docker compose -f "$(COMPOSE_FILE)" up -d; \
	elif [ "$(CONTAINER_RUNTIME)" = "podman" ]; then \
		podman compose -f "$(COMPOSE_FILE)" up -d || podman-compose -f "$(COMPOSE_FILE)" up -d; \
	fi

bootstrap:
	@kubectl get nodes >/dev/null
	@kubectl apply -k infrastructure/argocd/overlays/local
	@kubectl patch configmap argocd-cmd-params-cm -n "$(ARGOCD_NAMESPACE)" \
		--patch '{"data":{"server.insecure":"true"}}' --type merge || true
	@kubectl -n "$(ARGOCD_NAMESPACE)" rollout status deploy/argocd-server --timeout=180s
	@echo "Using GITOPS_REPO_URL=$(GITOPS_REPO_URL)"
	@sed \
		-e 's|__REPO_URL__|$(GITOPS_REPO_URL)|g' \
		-e 's|__TARGET_REVISION__|$(TARGET_REVISION)|g' \
		"$(ROOT_APP_FILE)" | kubectl apply -f -

apps-install:
	@kubectl annotate application "$(ROOT_APP_NAME)" -n "$(ARGOCD_NAMESPACE)" argocd.argoproj.io/refresh=hard --overwrite
	@kubectl get applications -n "$(ARGOCD_NAMESPACE)"

argocd-password:
	@kubectl get secret -n "$(ARGOCD_NAMESPACE)" argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

argocd-status:
	@kubectl get applications -n "$(ARGOCD_NAMESPACE)"

cloud-provider-down:
	@if [ "$(CONTAINER_RUNTIME)" = "docker" ]; then \
		docker compose -f "$(COMPOSE_FILE)" down --remove-orphans || true; \
	elif [ "$(CONTAINER_RUNTIME)" = "podman" ]; then \
		podman compose -f "$(COMPOSE_FILE)" down || podman-compose -f "$(COMPOSE_FILE)" down || true; \
	fi

cluster-down:
	@$(MAKE) cloud-provider-down
	@kind delete cluster --name "$(CLUSTER_NAME)"