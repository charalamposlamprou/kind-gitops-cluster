# Spec: DEVOPS-0002

## Summary
Remove the `validate-cluster` skill from the repository as it is superseded by the `validate-manifests` skill introduced in DEVOPS-0001.

## Context
The `validate-cluster` skill covers end-to-end cluster health checks (Argo CD sync status, ingress, OTel pipeline). With the SDD workflow now in place, manifest validation is handled by `validate-manifests`, and full cluster validation is a runtime/ops concern rather than a development workflow step. Having both skills risks confusion about which to use and when.

## Requirements
- [ ] `.github/skills/validate-cluster/` directory and all its contents are deleted
- [ ] Any references to `validate-cluster` in `.github/copilot-instructions.md` are removed
- [ ] Any references to `validate-cluster` in `README.md` are removed
- [ ] No broken links or dangling references remain in any file

## Acceptance Criteria
- [ ] `ls .github/skills/` shows only `validate-manifests`
- [ ] `grep -r "validate-cluster" .github/ README.md` returns no matches
- [ ] `kubectl kustomize applications/` and `kubectl kustomize infrastructure/` both pass

## Out of Scope
- Removing or modifying the `validate-manifests` skill
- Updating any GitHub Actions workflows
- Changes to `Makefile` targets (`make test-otel`, `make test-ingress` are separate from this skill)

## References
- `.github/skills/validate-cluster/SKILL.md` — file to delete
- `.github/copilot-instructions.md` — references to remove
- `README.md` — references to remove
- DEVOPS-0001 — introduced `validate-manifests` which replaces this skill
