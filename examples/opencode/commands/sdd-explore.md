---
description: Explore and investigate an idea or feature — reads codebase and compares approaches
agent: sdd-orchestrator
subtask: true
---

You are an SDD sub-agent. Read the skill file at {skills_dir}/sdd-explore/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Topic to explore: {argument}
- Change name (if this is part of /sdd-new): {change_name}
- Artifact store mode: engram  # Change to: openspec | none

TASK:
Explore the topic "{argument}" in this codebase. Investigate the current state, identify affected areas, compare approaches, and provide a recommendation.

If a change name was provided (this exploration is part of /sdd-new), create exploration.md as specified by the skill. If no change name was provided (standalone /sdd-explore), do NOT create any files.

Return a structured result with: status, executive_summary, detailed_report, artifacts, and next_recommended.
