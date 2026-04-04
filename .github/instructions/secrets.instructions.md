---
description: "Use when creating, handling, or reviewing Kubernetes Secrets in this repository. Covers Sealed Secrets workflow with kubeseal, naming conventions, and what must never be committed to Git."
applyTo: "**/*sealed*.yaml"
---

# Secrets Management

## Rule: never commit a raw `Secret` to Git

Any `kind: Secret` manifest committed to this repository must first be encrypted with `kubeseal`. The Sealed Secrets controller (running in `sealed-secrets` namespace, managed by Argo CD) is the only entity that can decrypt it.

## Sealing a secret

### Prerequisites

```bash
brew install kubeseal   # macOS
# or see infrastructure/sealed-secrets/README.md for Linux
```

The cluster must be running with the Sealed Secrets controller healthy (deployed automatically by `make bootstrap && make apps-install`).

### Workflow

```bash
# 1. Create the raw secret (dry-run only — never apply)
kubectl create secret generic <secret-name> \
  --namespace <namespace> \
  --from-literal=key=value \
  --dry-run=client -o yaml > /tmp/raw-secret.yaml

# 2. Seal it (fetches cert from the live controller)
kubeseal \
  --controller-namespace sealed-secrets \
  --controller-name sealed-secrets \
  --format yaml \
  < /tmp/raw-secret.yaml > <path-in-repo>/sealed-<secret-name>.yaml

# 3. Clean up the raw secret immediately
rm /tmp/raw-secret.yaml

# 4. Commit only the SealedSecret
git add <path-in-repo>/sealed-<secret-name>.yaml
```

### Offline sealing (for CI or no cluster access)

```bash
# Save the cert once (requires cluster access)
kubeseal --controller-namespace sealed-secrets \
         --fetch-cert > /tmp/sealed-secrets-cert.pem

# Seal offline using saved cert
kubeseal --cert /tmp/sealed-secrets-cert.pem --format yaml \
  < /tmp/raw-secret.yaml > sealed-<secret-name>.yaml
```

Refer to [infrastructure/sealed-secrets/README.md](../../infrastructure/sealed-secrets/README.md) for full details.

## Placement

Place `SealedSecret` manifests next to the component that consumes them:

| Consumer | Location |
|----------|---------|
| Infrastructure component | `infrastructure/<name>/sealed-<secret-name>.yaml` |
| Microservice | `applications/microservices/<name>/sealed-<secret-name>.yaml` |

Add the file to the local `kustomization.yaml` resources list.

## Naming conventions

- File: `sealed-<secret-name>.yaml`
- `metadata.name`: same as the original `Secret` name the app expects
- `metadata.namespace`: must match the namespace where the pod consuming the secret runs

## SealedSecret template

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: <secret-name>
  namespace: <namespace>
spec:
  encryptedData:
    <key>: <kubeseal-encrypted-value>
  template:
    metadata:
      name: <secret-name>
      namespace: <namespace>
```

## Rotating a secret

1. Re-create the raw secret with the new value.
2. Re-seal using the current controller cert.
3. Replace the existing `SealedSecret` file in the repo and push.
4. Argo CD syncs → controller decrypts → Kubernetes `Secret` is updated.
