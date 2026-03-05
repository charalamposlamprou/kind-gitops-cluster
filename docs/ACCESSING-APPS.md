# Accessing Applications in Kind - Complete Guide

This guide shows **5 different ways** to access your applications running in Kind, **without editing /etc/hosts**.

## Current Setup

Your cluster uses:
- **HAProxy Ingress Controller** with LoadBalancer service
- **cloud-provider-kind** for LoadBalancer support (creates envoy proxy)
- **nip.io DNS** for wildcard resolution (*.127.0.0.1.nip.io)
- **Kind extraPortMappings** on control-plane (8080:80, 8443:443)

---

## Option 1: nip.io DNS (Current - Easiest) ✅

**No configuration changes needed!** Your ingresses already use `*.127.0.0.1.nip.io`:

```bash
# Find the current envoy port
ENVOY_HTTP=$(docker port $(docker ps --filter "ancestor=envoyproxy/envoy:v1.33.2" -q) 80/tcp | cut -d':' -f2)
ENVOY_HTTPS=$(docker port $(docker ps --filter "ancestor=envoyproxy/envoy:v1.33.2" -q) 443/tcp | cut -d':' -f2)

# Access apps via nip.io
curl http://demo.127.0.0.1.nip.io:${ENVOY_HTTP}
curl http://grafana.127.0.0.1.nip.io:${ENVOY_HTTP}
curl http://prometheus.127.0.0.1.nip.io:${ENVOY_HTTP}

# Or in browser
open "http://demo.127.0.0.1.nip.io:${ENVOY_HTTP}"
open "http://grafana.127.0.0.1.nip.io:${ENVOY_HTTP}"
```

**Pros:**
- ✅ Already configured - works immediately
- ✅ No /etc/hosts modification
- ✅ Real DNS service (nip.io)
- ✅ Works for any subdomain

**Cons:**
- ⚠️ Port changes when cluster is recreated
- ⚠️ Random high port number (e.g., 63404)

### Make it easier with a helper command

Add to your Makefile:

```makefile
.PHONY: urls
urls:
	@echo "=== Application URLs ==="
	@ENVOY_PORT=$$(docker port $$(docker ps --filter "ancestor=envoyproxy/envoy:v1.33.2" -q) 80/tcp | cut -d':' -f2) && \
	echo "Demo App:    http://demo.127.0.0.1.nip.io:$$ENVOY_PORT" && \
	echo "Grafana:     http://grafana.127.0.0.1.nip.io:$$ENVOY_PORT" && \
	echo "Prometheus:  http://prometheus.127.0.0.1.nip.io:$$ENVOY_PORT" && \
	echo "Argo CD:     http://argocd.127.0.0.1.nip.io:$$ENVOY_PORT"
```

Then just run: `make urls`

---

## Option 2: kubectl port-forward (Quick & Simple) 🚀

No configuration needed. Access services directly:

```bash
# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Open: http://localhost:3000

# Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Open: http://localhost:9090

# Argo CD
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Open: https://localhost:8080

# Demo app
kubectl port-forward -n apps svc/service-a 8081:80
# Open: http://localhost:8081
```

**Pros:**
- ✅ No configuration changes
- ✅ Uses standard ports (3000, 9090, 8080)
- ✅ Works immediately
- ✅ Secure (only accessible from localhost)

**Cons:**
- ❌ Must keep terminal open
- ❌ One command per service
- ❌ Doesn't test ingress rules

---

## Option 3: NodePort + Fixed Kind Port Mappings 🎯

Use fixed, predictable ports by switching to NodePort.

### Step 1: Update kind-config.yaml

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080  # NodePort for HTTP
        hostPort: 80
        protocol: TCP
      - containerPort: 30443  # NodePort for HTTPS
        hostPort: 443
        protocol: TCP
  - role: worker
  - role: worker
  - role: worker
```

### Step 2: Update HAProxy to use NodePort

```yaml
# infrastructure/ingress/haproxy-application.yaml
controller:
  ingressClass: haproxy
  service:
    type: NodePort
    nodePorts:
      http: 30080   # Fixed port
      https: 30443  # Fixed port
```

### Step 3: Recreate cluster

```bash
make cluster-down
make cluster-up
make bootstrap
make apps-install
```

### Step 4: Access apps

```bash
# Now you can use standard ports!
curl http://demo.127.0.0.1.nip.io
curl http://grafana.127.0.0.1.nip.io
open http://demo.127.0.0.1.nip.io
```

**Pros:**
- ✅ Standard ports (80, 443)
- ✅ No random ports
- ✅ Works with nip.io or /etc/hosts
- ✅ Tests real ingress routing

**Cons:**
- ❌ Requires cluster recreation
- ❌ More complex configuration
- ❌ NodePort range limitations (30000-32767)

---

## Option 4: hostPort with DaemonSet 🏃

HAProxy pods bind directly to node ports.

### Update HAProxy configuration:

```yaml
# infrastructure/ingress/haproxy-application.yaml
controller:
  ingressClass: haproxy
  kind: DaemonSet  # Run on every node
  daemonset:
    useHostPort: true  # Bind to ports 80/443 on nodes
  service:
    type: ClusterIP  # Don't need LoadBalancer anymore
```

### Access apps

With your existing kind-config.yaml port mappings:

```bash
# Already mapped: control-plane:80 -> host:8080
curl http://demo.127.0.0.1.nip.io:8080
curl http://grafana.127.0.0.1.nip.io:8080
open http://demo.127.0.0.1.nip.io:8080
```

**Pros:**
- ✅ No cloud-provider-kind needed
- ✅ Direct node port binding
- ✅ Predictable ports
- ✅ High availability (DaemonSet on all nodes)

**Cons:**
- ❌ Port conflicts if other processes use 80/443
- ❌ Requires privileged containers

---

## Option 5: Access via Envoy Proxy Port with Host Header 🔄

Access apps through the envoy proxy port using curl with Host header.

### Find the envoy proxy port:

```bash
docker port $(docker ps --filter "ancestor=envoyproxy/envoy:v1.33.2" -q) 80/tcp
# Output: 0.0.0.0:49383
```

### Access using curl with Host header:

```bash
# Use curl with the Host header to specify the hostname
curl -H "Host: demo.127.0.0.1.nip.io" http://localhost:49383
curl -H "Host: grafana.127.0.0.1.nip.io" http://localhost:49383
curl -H "Host: prometheus.127.0.0.1.nip.io" http://localhost:49383
```

**Pros:**
- ✅ Tests ingress host-based routing
- ✅ Works without browser
- ✅ Useful for automation/scripts
- ✅ No need to modify /etc/hosts

**Cons:**
- ⚠️ Port changes when cluster is recreated
- ⚠️ Not convenient for browser access
- ⚠️ Must specify Host header for each request

---

## Comparison Table

| Method | Ports | DNS Needed | Cluster Rebuild | Ingress Testing | Complexity |
|--------|-------|------------|-----------------|-----------------|------------|
| **nip.io (current)** | Random | ✅ Auto | ❌ No | ✅ Yes | ⭐ Easy |
| **port-forward** | Standard | ❌ No | ❌ No | ❌ No | ⭐ Easy |
| **NodePort** | Fixed | ✅ Any | ⚠️ Once | ✅ Yes | ⭐⭐ Medium |
| **hostPort** | Fixed | ✅ Any | ⚠️ Once | ✅ Yes | ⭐⭐⭐ Advanced |
| **Host header (curl)** | Random | ❌ No | ❌ No | ✅ Yes | ⭐ Easy |

---

## Recommendation 🎯

**For everyday use:** Stick with **Option 1 (nip.io)** - it already works!

Add this helper to your Makefile:

```makefile
.PHONY: urls
urls:
	@ENVOY_PORT=$$(docker port $$(docker ps -q --filter "ancestor=envoyproxy/envoy:v1.33.2") 80/tcp 2>/dev/null | cut -d':' -f2) && \
	echo "📱 Application URLs:" && \
	echo "   Demo:       http://demo.127.0.0.1.nip.io:$$ENVOY_PORT" && \
	echo "   Grafana:    http://grafana.127.0.0.1.nip.io:$$ENVOY_PORT (admin/admin)" && \
	echo "   Prometheus: http://prometheus.127.0.0.1.nip.io:$$ENVOY_PORT" && \
	echo "   Argo CD:    http://argocd.127.0.0.1.nip.io:$$ENVOY_PORT"
```

Then: `make urls` → copy/paste URLs into browser!

**For production-like setup:** Use **Option 3 (NodePort)** for fixed ports 80/443.

**For quick testing:** Use **Option 2 (port-forward)** for individual services.

---

## Example Files Created

See these files for complete configurations:

- `infrastructure/ingress/haproxy-nodeport-example.yaml` - NodePort configuration
- `infrastructure/ingress/haproxy-hostport-example.yaml` - hostPort configuration  
- `infrastructure/cluster/kind-config-nodeport-example.yaml` - Kind config for NodePort

To use any example:
1. Copy the example file over the current config
2. Commit and push to Git
3. Argo CD will sync automatically (or run `make apps-install`)
