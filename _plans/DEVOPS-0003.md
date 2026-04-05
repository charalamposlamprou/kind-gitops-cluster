# Plan: DEVOPS-0003

## Branch
`DEVOPS-0003`

## Summary
Update CHANGELOG.md with entries for DEVOPS-0001 and DEVOPS-0002, and add missing instruction file references (`ci.instructions.md`, `secrets.instructions.md`) to `plan.prompt.md`.

## Files to Create
| File | Purpose |
|------|---------|
| _(none)_ | |

## Files to Modify
| File | Change |
|------|--------|
| `CHANGELOG.md` | Add `## [3.2.0] - 2026-04-05` entry with `feat:` for SDD workflow (DEVOPS-0001) and `chore:` for validate-cluster removal (DEVOPS-0002) |
| `.github/prompts/plan.prompt.md` | Add `ci.instructions.md` and `secrets.instructions.md` to the instruction list in Step 2 |

## Implementation Steps
1. Insert a new `## [3.2.0] - 2026-04-05` section at the top of `CHANGELOG.md` (after the `---` separator, before `## [3.1.0]`) with:
   - `### ✨ New Features` — SDD workflow entry (DEVOPS-0001): prompts, templates, skill, README section
   - `### 🛠 Infrastructure` — validate-cluster skill removal entry (DEVOPS-0002)
2. Add `ci.instructions.md` (if applicable) and `secrets.instructions.md` (if applicable) to the instruction list in Step 2 of `.github/prompts/plan.prompt.md`
3. Run `validate-manifests` skill to confirm no manifests were broken

## Validation
- [ ] `grep "3.2.0" CHANGELOG.md` returns a match
- [ ] `grep "SDD\|Spec-Driven" CHANGELOG.md` returns a match
- [ ] `grep "ci.instructions" .github/prompts/plan.prompt.md` returns a match
- [ ] `grep "secrets.instructions" .github/prompts/plan.prompt.md` returns a match
- [ ] `kubectl kustomize applications/` passes
- [ ] `kubectl kustomize infrastructure/` passes

## Risks / Decisions
- Version bump: DEVOPS-0001 introduced new features (`feat:`) → minor bump from 3.1.0 → 3.2.0 per conventional commit rules
- DEVOPS-0002 is a `chore:` (no release on its own) but lands in the same 3.2.0 entry since both are being backfilled together
- `ci.instructions.md` and `secrets.instructions.md` are marked `(if applicable)` — same pattern as existing instructions in `plan.prompt.md`
