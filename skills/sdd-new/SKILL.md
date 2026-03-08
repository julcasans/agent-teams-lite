---
name: sdd-new
description: >
  Start a new SDD change: run exploration then create a proposal.
  Trigger: When the user says `/sdd-new <change-name>` to begin a new named change.
license: MIT
metadata:
  author: gentleman-programming
  version: "2.0"
---

## Purpose

You are the SDD ORCHESTRATOR handling the `/sdd-new` meta-command. You coordinate two sub-agent phases (explore → propose) to start a new named change.

**Do not execute phase work inline.** Delegate to sub-agents and present summaries to the user.

## What You Receive

From the user:
- Change name (e.g., "add-csv-export")
- Artifact store mode (from the orchestrator context)

## What to Do

### Step 1: Launch sdd-explore

Spawn a sub-agent with:
- Skill: `sdd-explore/SKILL.md`
- Context: change name, project, mode
- Task: investigate the codebase for this change

Wait for the sub-agent to return its structured result.

### Step 2: Present Exploration to User

Show the user a concise summary:
- Current state of the affected areas
- Recommended approach
- Key risks

Ask: "Exploration complete. Shall I create a proposal based on this analysis?"

### Step 3: Launch sdd-propose (on approval)

If the user approves, spawn a sub-agent with:
- Skill: `sdd-propose/SKILL.md`
- Context: change name, project, mode, exploration result
- Task: create the proposal

### Step 4: Present Proposal to User

Show the user a concise summary:
- Intent
- Scope (in/out)
- Risk level
- Next step options

Ask: "Proposal created. Run `/sdd-ff {change-name}` to plan (spec + design + tasks), or `/sdd-spec` and `/sdd-design` individually?"

### Step 5: Persist State

After both phases complete, persist DAG state:
- **engram mode:** `mem_save(topic_key: "sdd/{change-name}/state", content: "phase: propose\nartifacts:\n  explore: true\n  proposal: true\n  spec: false\n  design: false\n  tasks: false")`
- **openspec mode:** Write `openspec/changes/{change-name}/state.yaml` with current phase and artifact status.

## Rules

- NEVER execute exploration or proposal work inline — always delegate to sub-agents.
- ALWAYS present a summary between phases and give the user a chance to review.
- If exploration reveals the change is too vague or risky, surface that information clearly.
- Pass the full exploration result to sdd-propose as context.
- Mode is set by the orchestrator and must be passed unchanged to every sub-agent.
