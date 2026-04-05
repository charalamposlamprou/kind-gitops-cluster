# Plan: DEVOPS-0002

## Branch
`DEVOPS-0002`

## Summary
Remove the `validate-cluster` skill from the repository as it is superseded by the `validate-manifests` skill introduced in DEVOPS-0001.

## Files to Create
| File | Purpose |
|------|---------|
| _(none)_ | |

## Files to Delete
| File | Reason |
|------|--------|
| `.github/skills/validate-cluster/SKILL.md` | Skill being removed |
| `.github/skills/validate-cluster/` (directory) | Clean up after file deletion |

## Files to Modify
| File | Change |
|------|--------|
| `.github/copilot-instructions.md` | Remove the `/validate-cluster` row from the Other Commands table |

## Implementation Steps
1. Delete `.github/skills/validate-cluster/SKILL.md` and the directory
2. Remove the `/validate-cluster` row from the `Other Commands` table in `.github/copilot-instructions.md`
3. Run `validate-manifests` skill to confirm no manifests were broken

## Validation
- [ ] `ls .github/skills/` shows only `validate-manifests`
- [ ] `grep -r "validate-cluster" .github/ README.md` returns no matches (only `_specs/DEVOPS-0002.md` is expected — that's the spec itself)
- [ ] `kubectl kustomize applications/` passes
- [ ] `kubectl kustomize infrastructure/` passes

## Risks / Decisions
- `README.md` has no references to `validate-cluster` — confirmed by grep, no change needed there
- The spec references `validate-cluster` by design (it's documenting what is being removed) — those matches in `_specs/DEVOPS-0002.md` are expected and do not need to be removed
- `Makefile` targets `make test-ingress`, `make test-otel`, `make argocd-status` are independent of this skill and are not affected
