# Spec: DEVOPS-0003

## Summary
Update CHANGELOG.md with entries for DEVOPS-0001 and DEVOPS-0002, and add missing instruction file references (`ci.instructions.md`, `secrets.instructions.md`) to `plan.prompt.md`.

## Context
Two gaps were identified after the SDD workflow was established:

1. **CHANGELOG not updated** — per `ci.instructions.md`, every PR must update `CHANGELOG.md` as part of the same PR. DEVOPS-0001 (SDD workflow introduction) and DEVOPS-0002 (validate-cluster skill removal) were merged without changelog entries.

2. **`plan.prompt.md` missing instruction references** — the `/plan` command only references `general`, `microservices`, `infrastructure`, and `monitoring` instruction files. `ci.instructions.md` (covers workflows, conventional commits) and `secrets.instructions.md` (covers Sealed Secrets) are missing. Tasks touching those areas will produce plans that miss those conventions.

## Requirements
- [ ] `CHANGELOG.md` has a new version entry (3.2.0) with sections for DEVOPS-0001 and DEVOPS-0002
- [ ] `plan.prompt.md` references `ci.instructions.md` (if applicable) and `secrets.instructions.md` (if applicable) in the instruction list

## Acceptance Criteria
- [ ] `CHANGELOG.md` contains a `## [3.2.0]` entry with entries for the SDD workflow addition and validate-cluster skill removal
- [ ] `plan.prompt.md` instruction list includes `ci.instructions.md` and `secrets.instructions.md`
- [ ] `kubectl kustomize applications/` passes
- [ ] `kubectl kustomize infrastructure/` passes

## Out of Scope
- Backfilling CHANGELOG entries for releases prior to 3.1.0
- Changes to the instruction files themselves

## References
- `CHANGELOG.md` — file to update
- `.github/prompts/plan.prompt.md` — file to update
- `.github/instructions/ci.instructions.md` — convention source for CHANGELOG format
- DEVOPS-0001 — `feat:` entries: SDD prompts, templates, README section
- DEVOPS-0002 — `chore:` entry: validate-cluster skill removal
