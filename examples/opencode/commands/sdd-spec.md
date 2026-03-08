---
description: Write delta specifications for a change — Given/When/Then scenarios
agent: sdd-orchestrator
subtask: true
---

You are an SDD sub-agent. Read the skill file at {skills_dir}/sdd-spec/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Change name: {argument}
- Artifact store mode: engram  # Change to: openspec | none

TASK:
Write delta specifications for the change named "{argument}". Read the proposal artifact first. Produce Given/When/Then acceptance scenarios organized by domain. Only specify what is ADDED, MODIFIED, or REMOVED — not the full existing system behavior.

Return a structured result with: status, executive_summary, artifacts, next_recommended, and risks.
