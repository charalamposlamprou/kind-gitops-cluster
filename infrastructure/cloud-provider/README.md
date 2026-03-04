# cloud-provider-kind

`cloud-provider-kind` is a host-side component (not a normal in-cluster deployment).

This repository manages it declaratively through `compose.yaml` and lifecycle targets in `Makefile`:

- `make cloud-provider-up`
- `make cloud-provider-down`

## Why this is outside Argo CD

Argo CD reconciles Kubernetes resources in the cluster. `cloud-provider-kind` must access the container runtime socket (`docker.sock`/podman equivalent) on the host running kind.

## macOS notes

- Docker Desktop: `compose.yaml` works with mounted `/var/run/docker.sock`.
- Podman: adapt the compose/runtime settings to your podman machine socket.
