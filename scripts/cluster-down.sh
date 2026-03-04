#!/bin/bash
set -e

CLUSTER_NAME="local-k8s-cluster"

# Detect container runtime (docker or podman)
if command -v docker &> /dev/null && command -v podman &> /dev/null; then
    echo "Both container runtimes are installed:"
    echo "  1) Docker"
    echo "  2) Podman"
    read -rp "Choose a runtime [1/2]: " choice

    case "$choice" in
        1) runtime="docker" ;;
        2) runtime="podman" ;;
        *)
            echo "❌ Invalid choice. Please enter 1 or 2."
            exit 1
            ;;
    esac

elif command -v docker &> /dev/null; then
    runtime="docker"

elif command -v podman &> /dev/null; then
    runtime="podman"

else
    echo "❌ Neither docker nor podman found. Please install one of them."
    exit 1
fi

echo "✅ Using container runtime: $runtime"

echo "[+] Deleting kind cluster..."
kind delete cluster --name "$CLUSTER_NAME"

echo "[+] Stopping and removing elb container..."
$runtime rm -f kind-cloud-elb 2>/dev/null || true

echo "[+] Removing kind-related $runtime resources..."
$runtime ps -a --filter "name=kind" --format "{{.ID}}" | xargs -r $runtime rm -f
$runtime volume ls --filter "name=kind" --format "{{.Name}}" | xargs -r $runtime volume rm
$runtime network rm kind >/dev/null 2>&1 || true
$runtime volume prune -f
$runtime image prune -f

rm -f podman.identity podman.url

echo "[✔] Cleanup complete."
