---
description: "Scaffold all 6 required manifest files for a new microservice and register it with Argo CD. Enforces Argo Rollout blue-green strategy and OpenTelemetry auto-instrumentation."
argument-hint: "Name of the new microservice (e.g. microservice-c)"
agent: "agent"
---

Scaffold a new microservice named **$ARGUMENTS** in this GitOps cluster.

Follow [.github/instructions/microservices.instructions.md](../instructions/microservices.instructions.md) for all conventions. Use the existing microservice-a manifests as the canonical reference:

- [applications/microservices/microservice-a/kustomization.yaml](../../applications/microservices/microservice-a/kustomization.yaml)
- [applications/microservices/microservice-a/deployment.yaml](../../applications/microservices/microservice-a/deployment.yaml)
- [applications/microservices/microservice-a/service.yaml](../../applications/microservices/microservice-a/service.yaml)
- [applications/microservices/microservice-a/preview-service.yaml](../../applications/microservices/microservice-a/preview-service.yaml)
- [applications/microservices/microservice-a/configmap.yaml](../../applications/microservices/microservice-a/configmap.yaml)
- [applications/microservices/microservice-a/ingress.yaml](../../applications/microservices/microservice-a/ingress.yaml)
- [applications/apps/microservice-a-application.yaml](../../applications/apps/microservice-a-application.yaml)
- [applications/kustomization.yaml](../../applications/kustomization.yaml)

## Steps

1. Create `applications/microservices/$ARGUMENTS/kustomization.yaml`
   - namespace: `apps`
   - resources: deployment.yaml, service.yaml, preview-service.yaml, configmap.yaml, ingress.yaml
   - labels with `app.kubernetes.io/name: $ARGUMENTS` and `app.kubernetes.io/part-of: microservices`

2. Create `applications/microservices/$ARGUMENTS/deployment.yaml`
   - `kind: Rollout`, `apiVersion: argoproj.io/v1alpha1`
   - Blue-green strategy: `activeService: service-$ARGUMENTS`, `previewService: service-$ARGUMENTS-preview`
   - `install-otel` init container (node:20-alpine, installs `@opentelemetry/auto-instrumentations-node` into `/otel`)
   - All 8 required OTEL env vars (see checklist in instructions); set `OTEL_SERVICE_NAME: $ARGUMENTS`
   - App code mounted from ConfigMap `$ARGUMENTS-app` at `/app/app.js`
   - Resources: requests cpu:100m/memory:128Mi, limits cpu:400m/memory:256Mi

3. Create `applications/microservices/$ARGUMENTS/service.yaml`
   - `name: service-$ARGUMENTS`, ClusterIP, port 80 → targetPort `http`

4. Create `applications/microservices/$ARGUMENTS/preview-service.yaml`
   - `name: service-$ARGUMENTS-preview`, ClusterIP, port 80 → targetPort `http`

5. Create `applications/microservices/$ARGUMENTS/configmap.yaml`
   - `name: $ARGUMENTS-app`
   - `app.js` key: a minimal Node.js HTTP server on port 80 that:
     - Returns JSON `{ service: "$ARGUMENTS", message: "hello from node", timestamp }` on `GET /`
     - Returns JSON `{ status: "ok", service: "$ARGUMENTS" }` on `GET /healthz`
   - Do **not** add any manual OTLP span code — the SDK instruments automatically

6. Create `applications/microservices/$ARGUMENTS/ingress.yaml`
   - `ingressClassName: haproxy`
   - host: `$ARGUMENTS.127.0.0.1.nip.io`
   - backend: `service-$ARGUMENTS` port 80

7. Create `applications/apps/$ARGUMENTS-application.yaml`
   - Standard Argo CD Application in namespace `argocd`
   - `path: applications/microservices/$ARGUMENTS`
   - `targetRevision: HEAD`
   - `syncPolicy.automated` with `prune: true`, `selfHeal: true`, `CreateNamespace=true`

8. Register in `applications/kustomization.yaml`
   - Add `- apps/$ARGUMENTS-application.yaml` to the `resources:` list

After creating all files, confirm the list of files created and remind the user to commit and push so Argo CD picks up the new application.
