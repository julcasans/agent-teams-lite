---
name: sdd-continue
description: >
  Continue the next missing artifact in the SDD dependency chain.
  Trigger: When the user says `/sdd-continue [change-name]` to resume an in-progress change.
license: MIT
metadata:
  author: gentleman-programming
  version: "2.0"
---

## Purpose

You are the SDD ORCHESTRATOR handling the `/sdd-continue` meta-command. You detect which artifact is next missing in the dependency chain and launch the appropriate sub-agent.

**Do not execute phase work inline.** Delegate to sub-agents.

## What You Receive

From the user:
- Optionally: change name (use the most recent active change if omitted)
- Artifact store mode (from the orchestrator context)

## Detection Algorithm

Before launching any sub-agent, determine what is next missing using this algorithm:

### engram mode detection

Search Engram for each artifact type in dependency order:

```
1. mem_search("sdd/{change-name}/proposal")  → exists? mark as ✅
2. mem_search("sdd/{change-name}/spec")       → exists? mark as ✅
3. mem_search("sdd/{change-name}/design")     → exists? mark as ✅
4. mem_search("sdd/{change-name}/tasks")      → exists? mark as ✅
5. mem_search("sdd/{change-name}/apply-progress") → exists? mark as ✅
6. mem_search("sdd/{change-name}/verify-report")  → exists? mark as ✅
7. mem_search("sdd/{change-name}/archive-report") → exists? mark as ✅
```

Also try to recover DAG state: `mem_search("sdd/{change-name}/state")` → `mem_get_observation(id)`.

Apply dependency rules:
- `proposal` missing → launch `sdd-propose`
- `proposal` exists, `spec` or `design` missing → launch missing one(s), may run in parallel
- `spec` and `design` both exist, `tasks` missing → launch `sdd-tasks`
- `tasks` exists (and has incomplete tasks), `apply-progress` missing or incomplete → launch `sdd-apply`
- `apply-progress` complete, `verify-report` missing → launch `sdd-verify`
- `verify-report` exists (no CRITICAL issues), `archive-report` missing → launch `sdd-archive`
- `archive-report` exists → change is closed; notify user

### openspec mode detection

Check filesystem for each artifact file in dependency order:

```
1. openspec/changes/{change-name}/proposal.md       → exists? ✅
2. openspec/changes/{change-name}/specs/             → has files? ✅
3. openspec/changes/{change-name}/design.md          → exists? ✅
4. openspec/changes/{change-name}/tasks.md           → exists? ✅ (and are all tasks [x]?)
5. openspec/changes/{change-name}/verify-report.md  → exists? ✅
6. openspec/changes/archive/ (contains change-name) → archived? ✅
```

Read `openspec/changes/{change-name}/state.yaml` if present for phase recovery.

Apply same dependency rules as engram mode above.

### none mode detection

In `none` mode, state is not persisted. Ask the user: "Which phase would you like to run? (propose/spec/design/tasks/apply/verify/archive)"

## What to Do After Detection

1. Report the current state to the user: which artifacts exist and which is next.
2. Launch the appropriate sub-agent(s) for the next missing phase.
3. After phase completes, update DAG state (engram: `mem_save` state; openspec: write `state.yaml`).
4. Present summary and ask whether to continue to the next phase.

## Rules

- ALWAYS run the detection algorithm before launching any sub-agent.
- If the change name is ambiguous, ask the user to clarify.
- If `archive-report` already exists, warn the user that the change is already closed.
- Mode is set by the orchestrator and must be passed unchanged to every sub-agent.
- Parallel execution: `spec` and `design` may launch simultaneously if both are missing.
