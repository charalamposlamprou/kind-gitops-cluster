---
description: "Execute the implementation plan for a task step by step."
argument-hint: "Task ID (e.g. DEVOPS-1234)"
agent: "agent"
---

You are implementing task **$ARGUMENTS**.

## Pre-flight checks

1. **Read the plan** at `_plans/$ARGUMENTS.md`. If it does not exist, stop and tell the engineer to run `/plan $ARGUMENTS` first.
2. **Confirm the current branch** is `$ARGUMENTS`:
   ```bash
   git branch --show-current
   ```
   If not on the correct branch, switch: `git checkout $ARGUMENTS`.
3. **Check for existing work** — if the branch already has commits ahead of `main`, warn the engineer:
   ```bash
   git log main..$ARGUMENTS --oneline
   ```
   If commits exist, tell the engineer:
   > "⚠️ Branch `$ARGUMENTS` already has commits ahead of `main`. This task may have been partially or fully implemented. Review the existing commits before proceeding to avoid duplicate work."
   Ask the engineer to confirm they want to continue before executing any further steps.

## Execution

Follow the **Implementation Steps** in `_plans/$ARGUMENTS.md` exactly, in order:
- Use `manage_todo_list` to track each step (mark in-progress before starting, completed immediately after finishing).
- After all files are created/modified, run the **Validation** checks from the plan.
- Do not add features, refactor, or make changes beyond what the plan specifies.

## Completion

When all steps and validation checks are done:

1. **Validate all manifests with kustomize** — run `kustomize build` on every kustomization entrypoint touched by this task. At minimum always validate:
   ```bash
   kubectl kustomize applications/
   kubectl kustomize infrastructure/
   ```
   If any additional kustomization paths were modified (e.g. `applications/microservices/<name>/`), run `kubectl kustomize` on those too.

   - If `kustomize build` **fails** on any path, **do not proceed**. Fix the error, re-run the build, and only continue once all builds succeed.
   - Tell the engineer which paths were validated and confirm they all passed.

2. **Stage and summarise** the changes (do not commit — let the engineer review first):
   ```bash
   git status && git diff --stat
   ```
3. Tell the engineer:
   > "All kustomize builds passed. Review the diff, then commit with: `git add . && git commit -m 'feat: <summary> ($ARGUMENTS)'`"
