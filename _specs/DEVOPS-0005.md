<!--
  SPEC-DRIVEN DEVELOPMENT — HOW TO USE THIS FILE
  ================================================
  1. Tell Copilot: "New task DEVOPS-XXXX: <your description>"
  2. Copilot creates the branch `DEVOPS-XXXX` from main
  3. Copilot generates this spec file from your description
  4. Review the spec — edit any section if something is wrong or missing
  5. Tell Copilot: "generate the plan" → it creates _plans/DEVOPS-XXXX.md
  6. Review the plan — approve or request changes
  7. Tell Copilot: "implement" → it executes the plan step by step

  DO NOT start implementation before the plan is approved.
  DO NOT skip the spec — it is the source of truth for the plan.
-->

# Spec: DEVOPS-0005

## Summary
Scale the microservice-b Argo Rollout replicas down from 4 to 2.

## Context
microservice-b was scaled up to 4 replicas in DEVOPS-0004. This task reverts that change, reducing replicas back to 2.

## Requirements
- [ ] `spec.replicas` in `applications/microservices/microservice-b/deployment.yaml` must be changed from `4` to `2`.
- [ ] No other files should be modified (beyond CHANGELOG.md).
- [ ] `kubectl kustomize applications/` must pass with no errors after the change.

## Acceptance Criteria
- [ ] `spec.replicas: 2` is present in `applications/microservices/microservice-b/deployment.yaml`
- [ ] `kubectl kustomize applications/` exits 0
- [ ] CHANGELOG.md updated with an entry for the replica scale-down
- [ ] Conventional commit on branch `DEVOPS-0005`

## Out of Scope
- Changing resource requests/limits
- Scaling microservice-a or any infrastructure component
- Updating HPA or PodDisruptionBudget

## References
- `applications/microservices/microservice-b/deployment.yaml`
- DEVOPS-0004 (original scale-up task)
