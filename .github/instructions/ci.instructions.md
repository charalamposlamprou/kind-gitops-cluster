---
description: "Use when creating, editing, or reviewing GitHub Actions workflows under .github/workflows/. Covers the validation and release pipelines, conventional commit format, and branch strategy."
applyTo: ".github/workflows/**"
---

# CI/CD Workflows

## Git workflow

```
feature/<short-description>   ← develop here
         ↓  Pull Request
       main                   ← protected; all CI must pass before merge
```

- **Never push directly to `main`**. All changes go through a PR.
- Branch naming: `feature/<description>`, `fix/<description>`, `chore/<description>`
- PRs targeting `main` trigger the `k8s-validation` workflow automatically.

## Conventional commits

The release workflow parses commit messages to determine the next semantic version. Follow this format exactly:

| Prefix | Version bump | Example |
|--------|-------------|---------|
| `feat:` or `feat(<scope>):` | minor | `feat: add microservice-c` |
| `fix:` or `fix(<scope>):` | patch | `fix: correct ingress hostname` |
| `perf:` | patch | `perf: reduce rollout replicas` |
| `chore:`, `docs:`, `refactor:`, `test:`, `ci:` | no release | `chore: update dashboards` |
| `BREAKING CHANGE` in body or `!` after type | major | `feat!: redesign OTEL pipeline` |

A release is only created when a PR is **merged to `main`** — direct pushes are skipped.

## Existing workflows

### `k8s-validation.yml`
- **Triggers**: PRs to `main` and direct pushes to `main` touching manifests or workflow files
- **What it does**:
  1. Builds every `kustomization.yaml` with `kubectl kustomize`
  2. Validates rendered manifests with `kubeconform` against Kubernetes 1.33.1 schemas (`-strict`, `-ignore-missing-schemas` for CRDs)
  3. Validates `bootstrap/root-application.yaml` (placeholder tokens are tolerated by kubeconform)
- **Must pass** before merging any manifest change

### `release.yml`
- **Triggers**: push to `main` (post-merge)
- **What it does**: finds the merged PR, parses commit messages since the last tag, bumps semver, creates a Git tag + GitHub Release with auto-generated release notes
- **No manual tagging** — let the workflow handle versions

## Adding a new workflow

- Place it in `.github/workflows/<name>.yml`
- Use `actions/checkout@v4`, `azure/setup-kubectl@v4` for consistency with existing workflows
- Scope `permissions:` to the minimum required (prefer `contents: read`)
- Add `concurrency.cancel-in-progress: true` for PR workflows to avoid queuing
- Validate manifest changes in PR workflows; never in post-merge only

## What the CI does NOT do

- Build or push container images (microservice code lives in ConfigMaps, no image build step needed)
- Deploy to the cluster (Argo CD handles deployment from `main` via GitOps)
- Run `make cluster-up` (cluster tests run locally with `make test-ingress` and `make test-otel`)
