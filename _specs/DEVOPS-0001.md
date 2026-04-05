# Spec: DEVOPS-0001

## Summary
Introduce Spec-Driven Development (SDD) tooling to the repository so all engineers follow a consistent spec → plan → implement workflow for every task.

## Context
Without a structured workflow, changes are made ad-hoc without a clear record of what was planned, why decisions were made, or how to validate the result. SDD enforces a three-step process (spec, plan, implement) backed by Copilot slash commands, giving every engineer a repeatable and auditable way to work on this repository.

## Requirements
- [ ] `_specs/` directory exists at the repo root for storing spec files
- [ ] `_plans/` directory exists at the repo root for storing plan files
- [ ] `_specs/TEMPLATE.md` provides a reusable spec template with workflow instructions
- [ ] `_plans/TEMPLATE.md` provides a reusable plan template with a review checklist
- [ ] `/specs` slash command creates a branch and generates a spec from a description
- [ ] `/plan` slash command reads a spec and generates an implementation plan
- [ ] `/implement` slash command executes the plan, validates manifests, and stages the diff
- [ ] `/specs` aborts if the target branch already exists
- [ ] `/implement` warns if the branch already has commits ahead of `main`
- [ ] `/implement` runs `kubectl kustomize` on all touched paths and blocks commit if validation fails
- [ ] SDD workflow is documented in `README.md`
- [ ] SDD commands are registered in `.github/copilot-instructions.md`

## Acceptance Criteria
- [ ] `_specs/TEMPLATE.md` and `_plans/TEMPLATE.md` exist and contain clear engineer-facing instructions
- [ ] `.github/prompts/specs.prompt.md`, `plan.prompt.md`, and `implement.prompt.md` exist and are correctly wired as Copilot slash commands
- [ ] `README.md` contains a dedicated SDD section explaining the three-step workflow
- [ ] `.github/copilot-instructions.md` lists all three SDD commands under a dedicated section
- [ ] `kubectl kustomize applications/` and `kubectl kustomize infrastructure/` both pass after the changes

## Out of Scope
- CI pipeline changes (kubeconform, GitHub Actions)
- Automating spec/plan generation without Copilot
- Integration with external issue trackers (Jira, Linear, etc.)

## References
- `.github/prompts/` — existing slash command prompts for reference
- `.github/copilot-instructions.md` — project-wide Copilot configuration
