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

### 2. Fetch the public certificate

```bash
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  > pub-sealed-secrets.pem
```

Save this certificate in your repo (it's public and safe to commit).

### 3. Create a SealedSecret

From a regular Kubernetes Secret YAML file:
```bash
# Create a secret (don't commit this!)
kubectl create secret generic my-secret \
  --from-literal=password=my-super-secret \
  --dry-run=client -o yaml > my-secret.yaml

# Encrypt it into a SealedSecret
kubeseal --format=yaml --cert=pub-sealed-secrets.pem \
  < my-secret.yaml > my-sealed-secret.yaml

# Commit the sealed secret safely
git add my-sealed-secret.yaml
git commit -m "Add sealed secret"
```

Or create directly from literals:
```bash
kubectl create secret generic my-app-secret \
  --from-literal=db-password=secretvalue \
  --from-literal=api-key=anothersecret \
  --dry-run=client -o yaml \
  | kubeseal --format yaml --cert pub-sealed-secrets.pem \
  > applications/my-app/sealed-secret.yaml
```

### 4. Apply the SealedSecret

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
# Fetch the new public cert
kubeseal --fetch-cert > pub-sealed-secrets-new.pem
```

## Scope Types

SealedSecrets support different scopes:

- **strict** (default): Secret tied to specific namespace and name
- **namespace-wide**: Can be unsealed to any name in the same namespace
- **cluster-wide**: Can be unsealed anywhere

Set scope when sealing:
```bash
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
