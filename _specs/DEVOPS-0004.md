# DEVOPS-0004 — Increase microservice-b replicas from 2 to 4

## Status
`draft`

## Summary
Scale the microservice-b Argo Rollout from 2 to 4 replicas to increase throughput capacity.

## Background
microservice-b currently runs with `replicas: 2` in `applications/microservices/microservice-b/deployment.yaml` (a `kind: Rollout`). No other services or configuration need to change.

## Requirements
- `spec.replicas` in `applications/microservices/microservice-b/deployment.yaml` must be changed from `2` to `4`.
- No other files should be modified.
- `kubectl kustomize applications/` must pass with no errors after the change.

## Out of Scope
- Changing resource requests/limits
- Scaling microservice-a or any infrastructure component
- Updating HPA or PodDisruptionBudget

## Acceptance Criteria
- [ ] `spec.replicas: 4` in `applications/microservices/microservice-b/deployment.yaml`
- [ ] `kubectl kustomize applications/` exits 0
- [ ] CHANGELOG.md updated under the correct unreleased/version section
- [ ] Conventional commit on branch `DEVOPS-0004`
