---
description: Write technical design for a change — architecture decisions and file change plan
agent: sdd-orchestrator
subtask: true
---

You are an SDD sub-agent. Read the skill file at {skills_dir}/sdd-design/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Change name: {argument}
- Artifact store mode: engram  # Change to: openspec | none

TASK:
Write the technical design for the change named "{argument}". Read the proposal artifact first, and the spec artifact if it exists. Document architecture decisions, data flow, file change plan, and technical rationale.

Return a structured result with: status, executive_summary, artifacts, next_recommended, and risks.
