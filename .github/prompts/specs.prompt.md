---
description: "Start a new SDD task: create a branch and generate the spec file from the task description."
argument-hint: "Task number and description (e.g. DEVOPS-1234 add microservice-c with health endpoint)"
agent: "agent"
---

You are starting a new Spec-Driven Development task.

The input is: **$ARGUMENTS**

Parse the input as: `<TASK_ID> <description>` where `TASK_ID` matches `DEVOPS-\d+`.

## Steps

1. **Check if the branch already exists** (both locally and remotely):
   ```bash
   git fetch origin 2>/dev/null; git branch --all | grep -w "<TASK_ID>"
   ```
   - If the branch **already exists** (locally or as `remotes/origin/<TASK_ID>`), **stop immediately** and tell the engineer:
     > "⚠️ Branch `<TASK_ID>` already exists. If you want to continue an existing task, switch to it with `git checkout <TASK_ID>`. If this is a mistake, delete the branch first with `git branch -d <TASK_ID>`. Aborting."
   - Do **not** create the spec file or proceed further until the engineer resolves the conflict.

2. **Create the branch** from `main`:
   ```bash
   git checkout main && git pull && git checkout -b <TASK_ID>
   ```

3. **Generate `_specs/<TASK_ID>.md`** using [_specs/TEMPLATE.md](../../_specs/TEMPLATE.md) as the structure. Fill every section from the description:
   - **Summary** — one sentence
   - **Context** — why this is needed
   - **Requirements** — concrete, testable bullet points
   - **Acceptance Criteria** — how to verify it is done
   - **Out of Scope** — what this task explicitly does not cover
   - **References** — any related files or tasks

4. Print a summary of the spec and tell the engineer:
   > "Spec created at `_specs/<TASK_ID>.md`. Review it, then run `/plan <TASK_ID>` to generate the implementation plan."
