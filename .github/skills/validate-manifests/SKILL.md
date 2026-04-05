---
name: validate-manifests
description: "Validate all Kubernetes manifests in the repository using kubectl kustomize. Run after any manifest change — as part of /implement or standalone before committing. Blocks on errors and reports which paths passed."
argument-hint: "Optional: space-separated list of additional kustomization paths to validate beyond the defaults (e.g. applications/microservices/microservice-c)"
---

# Validate Manifests

Runs `kubectl kustomize` on all kustomization entrypoints to confirm manifests are valid before committing.

## When to Use

- Automatically invoked by `/implement` before staging changes
- Manually, after editing any YAML manifest without going through `/implement`
- As a quick sanity check before opening a PR

## Procedure

### Step 1 — Always validate the two root entrypoints

```bash
kubectl kustomize applications/
kubectl kustomize infrastructure/
```

Both must pass. These cover all resources registered in their respective `kustomization.yaml` trees.

### Step 2 — Validate any additional paths touched by the task

If files were created or modified inside a sub-kustomization (e.g. a specific microservice directory), validate those paths too:

```bash
kubectl kustomize applications/microservices/<name>/
kubectl kustomize infrastructure/<component>/
```

If `$ARGUMENTS` was provided, validate each path listed there in addition to the defaults.

### Step 3 — Report results

For each path validated:
- ✅ **Pass** — tell the engineer: `"<path> ✓"`
- ❌ **Fail** — tell the engineer: `"<path> FAILED: <error message>"`, then **stop**. Do not proceed to staging or committing. Fix the error, re-run this skill, and only continue once all paths pass.

## Common errors and fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `no such file or directory` | New file not added to `kustomization.yaml` | Add the file to `resources:` in the relevant `kustomization.yaml` |
| `map: key already defined` | Duplicate key in a YAML manifest | Remove the duplicate key |
| `unknown field` | Typo in a field name or wrong API version | Check the field spelling against the resource spec |
| `accumulating resources` | Path in `kustomization.yaml` doesn't match actual filename | Fix the filename or the path entry |
