---
description: "Scaffold a new Helm-chart-based Argo CD Application under infrastructure/ and register it with the infra-app kustomization."
argument-hint: "Name of the new component (e.g. cert-manager)"
agent: "agent"
---

Scaffold a new infrastructure component named **$ARGUMENTS** in this GitOps cluster.

Follow [.github/instructions/infrastructure.instructions.md](../instructions/infrastructure.instructions.md) for all conventions. Use the existing HAProxy Application as the canonical reference:

- [infrastructure/ingress/haproxy-application.yaml](../../infrastructure/ingress/haproxy-application.yaml)
- [infrastructure/kustomization.yaml](../../infrastructure/kustomization.yaml)

## Steps

1. **Ask** (or infer from context) the following before creating any file:
   - Helm chart `repoURL` and `chart` name
   - `targetRevision` (exact chart version to pin)
   - Target `namespace` for the component
   - Any required Helm `values` to inline
   - Whether CRDs are included — if yes, the Application needs `argocd.argoproj.io/sync-wave: "-1"`; if this component depends on another component's CRDs, use wave `0` (default)

2. Create `infrastructure/$ARGUMENTS/` directory with:

   **`infrastructure/$ARGUMENTS/$ARGUMENTS-application.yaml`**
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: $ARGUMENTS
     namespace: argocd
     # annotations:
     #   argocd.argoproj.io/sync-wave: "-1"   # uncomment if this installs CRDs others depend on
   spec:
     project: default
     destination:
       server: https://kubernetes.default.svc
       namespace: <target-namespace>
     source:
       repoURL: <helm-repo-url>
       chart: <chart-name>
       targetRevision: <exact-chart-version>
       helm:
         releaseName: $ARGUMENTS
         values: |
           # inline Helm values here
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
         - CreateNamespace=true
   ```

   **`infrastructure/$ARGUMENTS/kustomization.yaml`**
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - $ARGUMENTS-application.yaml
   ```

3. Register in `infrastructure/kustomization.yaml`
   - Add `- $ARGUMENTS/` to the `resources:` list
   - If wave `-1` is needed, place it before wave-`0` components in the file for readability

After creating all files, confirm what was created and remind the user to commit and push so Argo CD picks up the new component.
