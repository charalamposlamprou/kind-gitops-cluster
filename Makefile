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

.PHONY: help cluster-up cluster-down bootstrap apps-install cloud-provider-up cloud-provider-down cloud-provider-wait argocd-password argocd-status urls test-ingress

help:
	@echo "GitOps lifecycle commands"
	@echo "  make cluster-up      - Create kind cluster + start cloud-provider-kind"
	@echo "  make cluster-down    - Stop cloud-provider-kind + delete cluster"
	@echo "  make bootstrap       - Initial Argo CD bootstrap (only imperative apply)"
	@echo "  make apps-install    - Refresh root App-of-Apps and show app status"
	@echo "  make urls            - Show all application URLs"
	@echo "  make test-ingress    - Test all ingress routes via LoadBalancer"
	@echo "  make argocd-password - Get Argo CD admin password"
	@echo "  make argocd-status   - Show Argo CD application status"

cluster-up:
	@if kind get clusters | grep -qx "$(CLUSTER_NAME)"; then \
		echo "Kind cluster '$(CLUSTER_NAME)' already exists"; \
	else \
		echo "Creating kind cluster '$(CLUSTER_NAME)'"; \
		kind create cluster --name "$(CLUSTER_NAME)" --config "$(KIND_CONFIG)"; \
	fi
	@$(MAKE) cloud-provider-down
	@$(MAKE) cloud-provider-up
	@$(MAKE) cloud-provider-wait
	@echo "cloud-provider-kind is ready."
	@echo "Envoy container is created only after a LoadBalancer service exists (e.g. after bootstrap/apps sync)."

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

cloud-provider-wait:
	@if [ "$(CONTAINER_RUNTIME)" = "docker" ]; then \
		for i in $$(seq 1 30); do \
			if docker logs kind-cloud-provider 2>&1 | grep -q "Starting service controller"; then \
				exit 0; \
			fi; \
			sleep 2; \
		done; \
		echo "cloud-provider-kind did not become ready in time"; \
		exit 1; \
	elif [ "$(CONTAINER_RUNTIME)" = "podman" ]; then \
		for i in $$(seq 1 30); do \
			if podman logs kind-cloud-provider 2>&1 | grep -q "Starting service controller"; then \
				exit 0; \
			fi; \
			sleep 2; \
		done; \
		echo "cloud-provider-kind did not become ready in time"; \
		exit 1; \
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

urls:
	@ENVOY_PORT=$$($(CONTAINER_RUNTIME) port $$($(CONTAINER_RUNTIME) ps -q --filter "ancestor=envoyproxy/envoy:v1.33.2") 80/tcp 2>/dev/null | cut -d':' -f2) && \
	if [ -z "$$ENVOY_PORT" ]; then \
		echo "⚠️  Envoy proxy not found. LoadBalancer services may not be ready yet."; \
		echo "Run 'make apps-install' and wait for apps to sync, then try again."; \
		exit 1; \
	fi && \
	echo "📱 Application URLs (via LoadBalancer):" && \
	echo "" && \
	echo "   🚀 Demo App:    http://demo.127.0.0.1.nip.io:$$ENVOY_PORT" && \
	echo "   📊 Grafana:     http://grafana.127.0.0.1.nip.io:$$ENVOY_PORT  (admin/admin)" && \
	echo "   📈 Prometheus:  http://prometheus.127.0.0.1.nip.io:$$ENVOY_PORT" && \
	echo "   🔄 Argo CD:     http://argocd.127.0.0.1.nip.io:$$ENVOY_PORT   (admin/$$PASSWORD)" && \
	echo "" && \
	echo "💡 Tip: Run 'make argocd-password' to get the Argo CD password"

test-ingress:
	@./scripts/test-ingress.sh