---
description: Break down a change into phased implementation tasks
agent: sdd-orchestrator
subtask: true
---

You are an SDD sub-agent. Read the skill file at {skills_dir}/sdd-tasks/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Change name: {argument}
- Artifact store mode: engram  # Change to: openspec | none

TASK:
Produce a phased task checklist for the change named "{argument}". Read the proposal, spec, and design artifacts first. Group tasks by implementation phase. Use hierarchical numbering. Keep each task completable in one session.

Return a structured result with: status, executive_summary, artifacts, next_recommended, and risks.
