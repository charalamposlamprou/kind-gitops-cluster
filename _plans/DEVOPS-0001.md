# Plan: DEVOPS-0001

## Branch
`DEVOPS-0001`

## Summary
Introduce Spec-Driven Development (SDD) tooling to the repository so all engineers follow a consistent spec → plan → implement workflow for every task.

## Files to Create
| File | Purpose |
|------|---------|
| `_specs/TEMPLATE.md` | Reusable spec template with engineer-facing workflow instructions |
| `_plans/TEMPLATE.md` | Reusable plan template with review checklist |
| `.github/prompts/specs.prompt.md` | `/specs` slash command — creates branch + generates spec |
| `.github/prompts/plan.prompt.md` | `/plan` slash command — reads spec + generates plan |
| `.github/prompts/implement.prompt.md` | `/implement` slash command — executes plan + validates + stages diff |
| `_specs/DEVOPS-0001.md` | Spec for this task |
| `_plans/DEVOPS-0001.md` | This file |

## Files to Modify
| File | Change |
|------|--------|
| `.github/copilot-instructions.md` | Add SDD section with the three slash commands under `## Prompts` |
| `README.md` | Add `## 🛠️ Contributing — Spec-Driven Development` section |

## Implementation Steps
1. Verify all files listed in "Files to Create" exist on disk ✓ (already done)
2. Verify all files listed in "Files to Modify" contain the SDD additions ✓ (already done)
3. Run `kubectl kustomize applications/` — must pass with no errors
4. Run `kubectl kustomize infrastructure/` — must pass with no errors
5. Stage all changes and confirm diff matches spec requirements

## Validation
- [ ] `_specs/TEMPLATE.md` exists and contains the 7-step workflow comment block
- [ ] `_plans/TEMPLATE.md` exists and contains the engineer review checklist comment block
- [ ] `.github/prompts/specs.prompt.md` exists with branch-existence check in Step 1
- [ ] `.github/prompts/plan.prompt.md` exists and references all instruction files
- [ ] `.github/prompts/implement.prompt.md` exists with kustomize validation in Completion section
- [ ] `.github/copilot-instructions.md` contains `### Spec-Driven Development (SDD)` section
- [ ] `README.md` contains `## 🛠️ Contributing — Spec-Driven Development` section
- [ ] `kubectl kustomize applications/` passes
- [ ] `kubectl kustomize infrastructure/` passes

## Risks / Decisions
- All files are already created as part of the initial SDD setup conversation — this task formalises and commits them
- `_specs/` and `_plans/` directories contain only `.md` files; no `.gitignore` changes needed
- Prompt files use `$ARGUMENTS` which is a Copilot-specific variable — no shell escaping required
