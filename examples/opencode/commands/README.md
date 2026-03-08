# OpenCode SDD Commands

This directory contains OpenCode command files for Spec-Driven Development.

## Command Types

OpenCode commands have two roles in the SDD workflow, determined by the `subtask` frontmatter field:

### Top-level commands (user-invocable, `subtask` not set)

These are entry points that users invoke directly (e.g., `/sdd-new add-feature`). They contain orchestration logic — they coordinate multiple sub-agents but do not execute phase work inline.

| Command | Purpose |
|---------|---------|
| `sdd-new.md` | Start a new change: explore → propose |
| `sdd-ff.md` | Fast-forward planning: propose → spec → design → tasks |
| `sdd-continue.md` | Resume next missing artifact in the dependency chain |

### Sub-agent commands (`subtask: true`)

These are invoked by OpenCode's Task mechanism, not directly by users. They execute exactly one SDD phase and return a structured result envelope.

| Command | Phase | Produces |
|---------|-------|---------|
| `sdd-init.md` | Initialize | Engram project context or `openspec/` structure |
| `sdd-explore.md` | Exploration | Analysis report (+ `exploration.md` if part of `/sdd-new`) |
| `sdd-propose.md` | Proposal | `proposal.md` or Engram `proposal` artifact |
| `sdd-spec.md` | Specification | Delta specs (Engram or `specs/` files) |
| `sdd-design.md` | Design | `design.md` or Engram `design` artifact |
| `sdd-tasks.md` | Task breakdown | `tasks.md` or Engram `tasks` artifact |
| `sdd-apply.md` | Implementation | Code changes + task completion marks |
| `sdd-verify.md` | Verification | `verify-report.md` or Engram `verify-report` artifact |
| `sdd-archive.md` | Archive | Spec merge + folder archive (openspec) or Engram `archive-report` |

## Adding a New Command

When adding a new SDD command, decide:

- **Is the user invoking it directly?** → Do NOT set `subtask: true`. Write orchestration logic.
- **Is it called via Task by an orchestrating command?** → Set `subtask: true`. Execute exactly one phase.

Choosing incorrectly means the command either appears in the wrong menu or fails to be orchestrated correctly.

## Path Resolution

All sub-agent commands reference skill files using the `{skills_dir}` placeholder:

```
Read the skill file at {skills_dir}/sdd-{phase}/SKILL.md FIRST
```

The `{skills_dir}` placeholder resolves to the platform-correct skills directory:
- **macOS/Linux:** `~/.config/opencode/skills`
- **Windows:** `%APPDATA%\opencode\skills`

## Artifact Store Mode

All commands default to `Artifact store mode: engram`. Each command file contains a comment (`# Change to: openspec | none`) on the mode line — edit that value in any command file to switch modes for that invocation.

> **Tip:** To change the default for all commands at once, run:
> ```bash
> sed -i '' 's/Artifact store mode: engram/Artifact store mode: openspec/' examples/opencode/commands/*.md
> ```
