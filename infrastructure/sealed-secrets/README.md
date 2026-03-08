# Sealed Secrets

[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) provides a secure way to store encrypted Kubernetes Secrets in Git repositories.

## Overview

- **Controller**: Runs in the `sealed-secrets` namespace
- **Chart Version**: 2.16.2
- **Managed by**: ArgoCD with auto-sync enabled

## Installation

Sealed Secrets is automatically deployed when you run:
```bash
make bootstrap
make apps-install
```

## Usage

### 1. Install kubeseal CLI

**macOS**:
```bash
brew install kubeseal
```

**Linux**:
```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.2/kubeseal-0.27.2-linux-amd64.tar.gz
tar xfz kubeseal-0.27.2-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

### 2. Create a SealedSecret

**Method 1: Direct cluster access (recommended)**

The simplest approach - `kubeseal` fetches the certificate automatically from the cluster:

```bash
# Create and seal in one command
kubectl create secret generic my-secret \
  --from-literal=password=my-super-secret \
  --dry-run=client -o yaml \
  | kubeseal \
      --controller-name=sealed-secrets-controller \
      --controller-namespace=sealed-secrets \
      --format yaml \
  > my-sealed-secret.yaml

# Commit the sealed secret safely
git add my-sealed-secret.yaml
git commit -m "Add sealed secret"
```

Example with multiple values:
```bash
kubectl create secret generic my-app-secret \
  --from-literal=db-password=secretvalue \
  --from-literal=api-key=anothersecret \
  --dry-run=client -o yaml \
  | kubeseal \
      --controller-name=sealed-secrets-controller \
      --controller-namespace=sealed-secrets \
      --format yaml \
  > applications/my-app/sealed-secret.yaml
```

**Method 2: Using a saved certificate (offline sealing)**

Useful for CI/CD pipelines or when cluster access isn't available:

```bash
# First, fetch and save the public certificate
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  > pub-sealed-secrets.pem

# Then use it to seal secrets offline
kubectl create secret generic my-secret \
  --from-literal=password=my-super-secret \
  --dry-run=client -o yaml \
  | kubeseal --format yaml --cert pub-sealed-secrets.pem \
  > my-sealed-secret.yaml
```

The certificate is public and safe to commit to Git if needed.

### 3. Apply the SealedSecret

The SealedSecret can be committed to Git. When applied to the cluster:
```bash
kubectl apply -f my-sealed-secret.yaml
```

The Sealed Secrets controller will automatically decrypt it and create the corresponding Secret.

## Verification

Check the controller is running:
```bash
kubectl get pods -n sealed-secrets
```

View controller logs:
```bash
kubectl logs -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets
```

## Backup

**IMPORTANT**: Back up your sealing key! If lost, you cannot decrypt existing SealedSecrets.

```bash
kubectl get secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > sealed-secrets-master-key-backup.yaml
```

Store this file securely (e.g., password manager, encrypted storage). **Never commit it to Git**.

## Key Rotation

The controller generates a new key every 30 days by default but keeps old keys to decrypt existing secrets. To manually renew:

```bash
kubectl delete secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active

# Controller will generate a new key automatically
```

After rotation, `kubeseal` will automatically use the new certificate when connected to the cluster. If you saved the certificate for offline use, fetch it again:

```bash
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  > pub-sealed-secrets.pem
```

## Scope Types

SealedSecrets support different scopes:

- **strict** (default): Secret tied to specific namespace and name
- **namespace-wide**: Can be unsealed to any name in the same namespace
- **cluster-wide**: Can be unsealed anywhere

Set scope when sealing:
```bash
# Using cluster connection
kubectl create secret generic my-secret \
  --from-literal=password=secret \
  --dry-run=client -o yaml \
  | kubeseal \
      --scope namespace-wide \
      --controller-name=sealed-secrets-controller \
      --controller-namespace=sealed-secrets \
      --format yaml

# Or with saved certificate
kubeseal --scope namespace-wide --cert pub-sealed-secrets.pem < secret.yaml
```

## Troubleshooting

**Secret not appearing**:
```bash
# Check SealedSecret exists
kubectl get sealedsecrets -A

# Check controller logs
kubectl logs -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets --tail=50
```

**Wrong certificate**:
If you sealed with an old certificate after key rotation, re-seal with the current one.

## References

- [Official Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [Helm Chart](https://github.com/bitnami-labs/sealed-secrets/tree/main/helm/sealed-secrets)
