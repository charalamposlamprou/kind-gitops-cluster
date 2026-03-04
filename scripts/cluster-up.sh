#!/bin/bash
set -e

REPO_URL="https://github.com/kubernetes-sigs/cloud-provider-kind.git"
REPO_DIR="cloud-provider-kind"
DOCKERFILE_PATH="$REPO_DIR/Dockerfile"

CLUSTER_NAME="local-k8s-cluster"
CONTAINER_NAME="kind-cloud-elb"
IMAGE_NAME="localhost/cloud-elb-kind"
IDENTITY_FILE="podman.identity"
PODMAN_IDENTITY_SOURCE="$HOME/.local/share/containers/podman/machine/machine"

# Versions
KUBE_VERSION="kindest/node:v1.32.0"
METRICS_SERVER_VERSION="v0.7.1"
PROMETHEUS_VERSION="v2.41.0"
GRAFANA_VERSION="9.5.5"
KEDA_VERSION="2.16.0"
HAPROXY_VERSION="3.2.6"
ARGOCD_VERSION="v3.3.2"



# List of required tools excluding container runtime (handled separately)
tools=("kind" "kubectl" "helm" "kustomize" "argocd" "kubectl-argo-rollouts")

# Track missing tools or issues
missing=()

echo "🔍 Checking for required tools..."

# Check other tools
for tool in "${tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "❌ $tool is not installed."
        missing+=("$tool")
    else
        echo "✅ $tool is installed."
    fi
done

# Summary
echo ""
if [ ${#missing[@]} -ne 0 ]; then
    echo "⚠️ Missing or not running: ${missing[*]}"
    exit 1
else
    echo "🎉 All required tools are installed and running. Continuing..."
fi

install_kind () {
    # Check if cluster already exists
    if kind get clusters | grep -qw "$CLUSTER_NAME"; then
        echo "⚠️ Kind cluster '${CLUSTER_NAME}' already exists. Proceeding..."
    else
        echo "[*] Creating kind cluster '${CLUSTER_NAME}'..."
        if kind create cluster --name "${CLUSTER_NAME}" --config config/kind-config.yaml --image $KUBE_VERSION; then
            echo "✅ Cluster created."
        else
            echo "❌ Failed to create cluster '${CLUSTER_NAME}'. Exiting."
            exit 1
        fi
    fi
}

echo "[+] Checking if cloud-provider-kind exists..."
if [ -d "$REPO_DIR" ]; then
    echo "Repository already exists at $REPO_DIR. Skipping clone."
else
    echo "[+] Cloning cloud-provider-kind..."
    git clone "$REPO_URL" "$REPO_DIR"
fi


run_with_podman() {

    # Ensure the iptable_nat kernel module is loaded inside the Podman VM (needed by istio-init)
    podman machine ssh "sudo modprobe iptable_nat || echo 'iptable_nat already loaded or not avaialable'"

    export KIND_EXPERIMENTAL_PROVIDER=podman

    install_kind

    if [ -f "$DOCKERFILE_PATH" ]; then
        echo "[+] Replacing base images in Dockerfile with Quay/Podman versions..."
        sed -i '' 's|^FROM docker:[^[:space:]]*|FROM quay.io/podman/stable:v5.5.1|' "$DOCKERFILE_PATH"
    fi

    if podman images -q "$IMAGE_NAME" 2> /dev/null | grep -q .; then
        echo "Image '$IMAGE_NAME' already exists. Skipping build."
    else
        echo "[+] Building elb image with Podman..."
        podman build -f "$DOCKERFILE_PATH" -t "$IMAGE_NAME" "$REPO_DIR"
    fi

    echo "[+] Cleaning up cloned repository..."
    rm -rf "$REPO_DIR"

    PORT=$(podman system connection list --format "{{.URI}} {{.Default}}" | awk '$2 == "true" {print $1}' | sed -E 's/.*:([0-9]+)\/.*/\1/')
    echo "$PORT"

    if [[ -z "$PORT" ]]; then
	echo "❌ Failed to extract the port from podman system connection list"
	exit 1
    fi

    # Check if identity file exists
    if [ ! -f "$IDENTITY_FILE" ]; then
	if [ -f "$PODMAN_IDENTITY_SOURCE" ]; then
	    echo "📁 Creating podman.identity from Podman machine identity file..."
	    cp "$PODMAN_IDENTITY_SOURCE" "$IDENTITY_FILE"
	    echo "✅ podman.identity created."
	else
            echo "❌ Could not find Podman identity source at $PODMAN_IDENTITY_SOURCE."
            exit 1
	fi
    else
	echo "🔐 podman.identity already exists. Proceeding..."
    fi

    echo "[+] Fetching UID from Podman machine..."

    # Get UID from inside the Podman machine (macOS uses XDG_RUNTIME_DIR to encode UID)
    uid_number=$(podman machine ssh 'bash -c "echo \$XDG_RUNTIME_DIR"' | grep -o '[0-9]\+')

    if [ -z "$uid_number" ]; then
        echo "❌ Failed to get UID from Podman machine. Aborting."
        exit 1
    fi

    CONTAINER_HOST="ssh://core@host.containers.internal:$PORT/run/user/$uid_number/podman/podman.sock"

    # Save to file
    echo "$CONTAINER_HOST" > podman.url

    echo "✅ CONTAINER_HOST set and saved to podman.url:"
    echo "$CONTAINER_HOST"

    echo "[+] Running lb as container with Podman..."


    # Check if container with that name exists (running or stopped)
    if podman ps -a --format "{{.Names}}" | grep -qw "$CONTAINER_NAME"; then
	echo "⚠️ Container '$CONTAINER_NAME' already exists. Proceeding..."
    else
	podman run --name "$CONTAINER_NAME" -e \
	    CONTAINER_HOST="$CONTAINER_HOST" \
	    -v "$(pwd)/$IDENTITY_FILE:/podman.identity" \
	    --network kind \
	    -e CONTAINER_SSHKEY=/podman.identity \
	    -d --rm "$IMAGE_NAME" -enable-lb-port-mapping

	echo "✅ Container '$CONTAINER_NAME' created."
    fi
}

run_with_docker() {

    export KIND_EXPERIMENTAL_PROVIDER=docker

    install_kind
     
    if docker images -q "$IMAGE_NAME" 2> /dev/null | grep -q .; then
        echo "Image '$IMAGE_NAME' already exists. Skipping build."
    else
        echo "[+] Building elb image with Docker..."
        docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_NAME" "$REPO_DIR"
    fi

    echo "[+] Cleaning up cloned repository..."
    rm -rf "$REPO_DIR"

    # Check if container with that name exists (running or stopped)
    if docker ps -a --format "{{.Names}}" | grep -qw "$CONTAINER_NAME"; then
    	echo "⚠️ Container '$CONTAINER_NAME' already exists. Proceeding..."
    else
      docker run -d --rm --network kind --name "$CONTAINER_NAME" \
        -v /var/run/docker.sock:/var/run/docker.sock "$IMAGE_NAME" \
        --enable-lb-port-mapping
#     docker run -d --rm --network kind --name "$CONTAINER_NAME" \
#       -v /var/run/docker.sock:/var/run/docker.sock "$IMAGE_NAME"
   	  echo "✅ Container '$CONTAINER_NAME' created."
    fi
}

install_helm_charts () {
    ################################
    # Install/Patch Metrics-server #
    ################################
    if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    echo "Metrics server already installed"
    else
    echo "Installing metrics-server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml

    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
        {
        "op": "add",
        "path": "/spec/template/spec/containers/0/args/-",
        "value": "--kubelet-insecure-tls"
        },
        {
            "op": "add",
            "path": "/spec/template/spec/containers/0/args/-",
            "value": "--kubelet-preferred-address-types=InternalIP"
        }
    ]'

    echo "Metrics-server installation completed."
    fi

    ###########################
    # Add/Update Repositories #
    ###########################
    echo "[+] Adding Helm repos..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || echo "Repo already exists, proceeding..."
    helm repo add grafana https://grafana.github.io/helm-charts || echo "Repo already exists, proceeding..."
    helm repo add kedacore https://kedacore.github.io/charts || echo "Repo already exists, proceeding..."
    helm repo add haproxytech https://haproxytech.github.io/helm-charts || echo "Repo already exists, proceeding..."
    helm repo add argo https://argoproj.github.io/argo-helm || echo "Repo already exists, proceeding..."
    helm repo update

    #####################
    # KEDA Installation #
    #####################
    if ! helm status keda -n keda &>/dev/null; then
    echo "Installing KEDA..."
    helm upgrade --install keda kedacore/keda \
        --version $KEDA_VERSION \
        --namespace keda --create-namespace
    echo "KEDA Installation completed."
    else
    echo "KEDA already installed, skipping..."
    fi

    ###########################
    # PROMETHEUS Installation #
    ###########################
    if ! helm status prometheus -n monitoring &>/dev/null; then
    echo "Installing PROMETHEUS..."
    helm upgrade --install prometheus prometheus-community/prometheus \
        --set server.image.repository="prom/prometheus" \
        --set server.image.tag=$PROMETHEUS_VERSION \
        --set nodeExporter.enabled=true \
        --namespace monitoring --create-namespace

    echo "PROMETHEUS Installation completed."
    else
    echo "PROMETHEUS already installed, skipping..."
    fi
    ########################
    # GRAFANA Installation #
    ########################
    if ! helm status grafana -n monitoring &>/dev/null; then
    echo "Installing GRAFANA..."
    helm upgrade --install grafana grafana/grafana \
        --set image.tag=$GRAFANA_VERSION \
        --namespace monitoring --create-namespace

        echo "GRAFANA Installation completed."
    else
    echo "GRAFANA already installed, skipping..."
    fi

    ########################
    # HAPROXY Installation #
    ########################
    if ! helm status haproxy -n networking &>/dev/null; then
        echo "Installing HAPROXY..."
        helm upgrade --install haproxy haproxytech/kubernetes-ingress \
            --set controller.image.tag=$HAPROXY_VERSION \
            --set controller.service.type=LoadBalancer \
            --namespace networking --create-namespace
        echo "HAPROXY Installation completed."
    else
        echo "HAPROXY already installed, skipping..."
    fi

    ########################
    # ARGO CD Installation #
    ########################
    if ! helm status argocd -n argocd &>/dev/null; then
        echo "Installing ARGO CD..."
        helm upgrade --install argocd argo/argo-cd \
            --set server.image.tag=$ARGOCD_VERSION \
            --namespace argocd --create-namespace
        echo "ARGO CD Installation completed."
    else
        echo "ARGO CD already installed, skipping..."
    fi

    # Enable insecure mode #
    echo "Enabling insecure mode..."
    kubectl patch configmap argocd-cmd-params-cm -n argocd \
        -p '{"data":{"server.insecure":"true"}}'

    echo "Restarting ArgoCD server..."
    kubectl rollout restart deployment/argocd-server -n argocd

    # Wait for the rollout to complete
    kubectl rollout status deployment/argocd-server -n argocd --timeout=2m

    if ! kubectl get crd rollouts.argoproj.io &>/dev/null; then
        echo "Installing Argo Rollouts..."
        kubectl create namespace argo-rollouts
        kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
        echo "Argo Rollouts installation completed."
    else
        echo "Argo Rollouts already installed, skipping..."
    fi

    #############################################################################################
    # Create an Ingress for monitoring applications and expose the HAProxy service on port 8080 #
    #############################################################################################
    kubectl apply -f config/ingress-argocd.yaml
    kubectl apply -f config/ingress-monitoring.yaml
    :> nohup.out
    nohup kubectl port-forward -n networking svc/haproxy-kubernetes-ingress 8080:80 2>&1 &
    echo "Port forward started on 8080"
    #############################################
    # Display Prometheus/Grafana access details #
    #############################################
    # Get Grafana password
    GRAFANA_PASSWORD=$(kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

    # Get Argo CD initial admin password
    ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode)

    # Display access information
    echo -e "\n› Monitoring & GitOps Apps setup done!"
    echo -e "[💻] Prometheus dashboard: http://prometheus.127.0.0.1.nip.io:8080"
    echo -e "[💻] Grafana dashboard: http://grafana.127.0.0.1.nip.io:8080"
    echo -e "[💻] Grafana username: admin"
    echo -e "[💻] Grafana password: $GRAFANA_PASSWORD"
    echo -e "[💻] Argo CD dashboard: http://argocd.127.0.0.1.nip.io:8080"
    echo -e "[💻] Argo CD username: admin"
    echo -e "[💻] Argo CD password: $ARGOCD_PASSWORD"

}

# Function to check for Docker or Podman and prompt user to choose if both exist
check_container_runtime() {
    local has_docker=false
    local has_podman=false
    local runtime=""

    # Check if Docker is installed
    if command -v docker &> /dev/null; then
        has_docker=true
    fi

    # Check if Podman is installed
    if command -v podman &> /dev/null; then
        has_podman=true
    fi

    # Determine which runtime to use
    if $has_docker && $has_podman; then
        echo "Both Docker and Podman are installed."
        echo "Which container runtime would you like to use?"
        echo "1) Docker"
        echo "2) Podman"
        read -p "Enter your choice (1 or 2): " choice
        
        case $choice in
            1)
                runtime="docker"
                echo "Using Docker"
                run_with_docker
                install_helm_charts
                ;;
            2)
                runtime="podman"
                echo "Using Podman"
                run_with_podman
                install_helm_charts
                ;;
            *)
                echo "Invalid choice."
                exit 1
                ;;
        esac
    elif $has_docker; then
        runtime="docker"
        echo "Using Docker"
        run_with_docker
        install_helm_charts
    elif $has_podman; then
        runtime="podman"
        echo "Using Podman"
        run_with_podman
        install_helm_charts
    else
        echo "Error: Neither Docker nor Podman is installed."
        exit 1
    fi

    # Export the runtime for use in other scripts
    export CONTAINER_RUNTIME="$runtime"
    echo "Container runtime set to: $CONTAINER_RUNTIME"
    return 0
}

check_container_runtime