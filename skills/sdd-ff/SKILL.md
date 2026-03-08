---
name: sdd-ff
description: >
  Fast-forward all SDD planning phases: proposal → spec → design → tasks (without exploration).
  Trigger: When the user says `/sdd-ff <change-name>` to run all planning phases in sequence.
license: MIT
metadata:
  author: gentleman-programming
  version: "2.0"
---

## Purpose

You are the SDD ORCHESTRATOR handling the `/sdd-ff` meta-command. You run four planning sub-agents in sequence (propose → spec → design → tasks) without a prior exploration phase.

> **Warning:** `/sdd-ff` skips exploration. The proposal will be based on user description only, without codebase investigation. For unfamiliar codebases or high-risk changes, consider `/sdd-new` (which includes exploration) instead.

**Do not execute phase work inline.** Delegate to sub-agents.

## What You Receive

From the user:
- Change name (e.g., "add-csv-export")
- A description of the change (may be provided inline or from prior conversation)
- Artifact store mode (from the orchestrator context)

## What to Do

### Step 1: Launch sdd-propose

Spawn a sub-agent with:
- Skill: `sdd-propose/SKILL.md`
- Context: change name, project, mode, user description (no exploration result)
- Task: create the proposal from user description

### Step 2: Launch sdd-spec and sdd-design in parallel

After proposal is complete, spawn two sub-agents simultaneously:

**sdd-spec sub-agent:**
- Skill: `sdd-spec/SKILL.md`
- Context: change name, project, mode, proposal result
- Task: write delta specifications

**sdd-design sub-agent:**
- Skill: `sdd-design/SKILL.md`
- Context: change name, project, mode, proposal result
- Task: write technical design

Wait for both to complete before proceeding.

### Step 3: Launch sdd-tasks

After both spec and design are complete, spawn a sub-agent with:
- Skill: `sdd-tasks/SKILL.md`
- Context: change name, project, mode, spec result, design result
- Task: produce the phased task checklist

### Step 4: Present Combined Summary

After ALL phases complete, present a single combined summary:
- Proposal: intent + scope
- Specs: domains covered + scenario count
- Design: key decisions + affected files
- Tasks: phase count + total task count

Ask: "Planning complete. Run `/sdd-apply {change-name}` to start implementation?"

### Step 5: Persist State

After all phases complete, persist DAG state:
- **engram mode:** `mem_save(topic_key: "sdd/{change-name}/state", content: "phase: tasks\nartifacts:\n  explore: false\n  proposal: true\n  spec: true\n  design: true\n  tasks: true")`
- **openspec mode:** Write `openspec/changes/{change-name}/state.yaml` with current phase and artifact status.

## Rules

- NEVER execute phase work inline — always delegate to sub-agents.
- NEVER show intermediate results between phases — present ONE combined summary at the end.
- Warn the user that exploration was skipped before starting.
- `sdd-spec` and `sdd-design` MAY run in parallel (both depend only on proposal). `sdd-tasks` MUST wait for both.
- Mode is set by the orchestrator and must be passed unchanged to every sub-agent.
