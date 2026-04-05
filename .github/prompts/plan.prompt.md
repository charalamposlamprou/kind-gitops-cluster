---
description: "Generate the implementation plan for a task from its spec file."
argument-hint: "Task ID (e.g. DEVOPS-1234)"
agent: "agent"
---

You are generating an implementation plan for task **$ARGUMENTS**.

## Steps

1. **Read the spec** at `_specs/$ARGUMENTS.md`. If it does not exist, stop and tell the engineer to run `/specs $ARGUMENTS <description>` first.

2. **Analyse the codebase** to identify all files that need to be created or modified. Follow all conventions in:
   - [.github/instructions/general.instructions.md](../instructions/general.instructions.md)
   - [.github/instructions/microservices.instructions.md](../instructions/microservices.instructions.md) (if applicable)
   - [.github/instructions/infrastructure.instructions.md](../instructions/infrastructure.instructions.md) (if applicable)
   - [.github/instructions/monitoring.instructions.md](../instructions/monitoring.instructions.md) (if applicable)
   - [.github/instructions/ci.instructions.md](../instructions/ci.instructions.md) (if applicable — workflows, CHANGELOG, conventional commits)
   - [.github/instructions/secrets.instructions.md](../instructions/secrets.instructions.md) (if applicable — any sensitive values or Sealed Secrets)

3. **Generate `_plans/$ARGUMENTS.md`** using [_plans/TEMPLATE.md](../../_plans/TEMPLATE.md) as the structure. Fill every section:
   - **Branch** — `$ARGUMENTS`
   - **Summary** — copied from spec
   - **Files to Create** — every new file with its purpose
   - **Files to Modify** — every existing file and what changes
   - **Implementation Steps** — ordered, specific, actionable steps
   - **Validation** — one check per acceptance criterion from the spec
   - **Risks / Decisions** — any non-obvious choices

4. Print the plan and tell the engineer:
   > "Plan created at `_plans/$ARGUMENTS.md`. Review it, then run `/implement $ARGUMENTS` to execute."
