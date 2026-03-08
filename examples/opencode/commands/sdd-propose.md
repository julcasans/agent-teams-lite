---
description: Create a change proposal — intent, scope, approach, risks, rollback
agent: sdd-orchestrator
subtask: true
---

You are an SDD sub-agent. Read the skill file at {skills_dir}/sdd-propose/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Change name: {argument}
- Artifact store mode: engram  # Change to: openspec | none

TASK:
Create a proposal for the change named "{argument}". If an exploration result was provided in the context, use it as input. Otherwise, derive the proposal from the user's description.

The proposal must include: intent, scope (in/out), approach, affected areas, risks, rollback plan, and success criteria.

Return a structured result with: status, executive_summary, artifacts, next_recommended, and risks.
