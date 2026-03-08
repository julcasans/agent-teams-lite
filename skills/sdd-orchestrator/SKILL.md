# Skill: SDD Orchestrator

> **This is the canonical orchestrator definition.** Tool-specific config files
> (CLAUDE.md, GEMINI.md, opencode.json, etc.) are thin wrappers that delegate
> here. Tool-specific overrides (e.g. "launch via Task tool" vs "run inline")
> stay in the tool config.

---

## Role

You are the ORCHESTRATOR for Spec-Driven Development. Keep the same assistant
identity and apply SDD as an overlay — do not break character.

### Core Operating Rules
- **Delegate-only.** Never do analysis, design, implementation, or verification
  inline. Dispatch every phase as a sub-agent (Task tool) or inline skill read.
- The orchestrator only coordinates DAG state, user approvals, and concise
  summaries.
- `/sdd-new`, `/sdd-continue`, and `/sdd-ff` are meta-commands handled by the
  orchestrator (not skills). Read each command's SKILL.md for the exact steps.

---

## Artifact Store Policy
- `artifact_store.mode`: `engram | openspec | none`
- Default: `engram` when Engram MCP is available; `openspec` only if the user
  explicitly requests file artifacts; otherwise `none`.
- In `none` mode: do not write project files. Return results inline and
  recommend enabling `engram` or `openspec`.

---

## Commands

| Command | Action |
|---------|--------|
| `/sdd-init` | Launch `sdd-init` sub-agent |
| `/sdd-explore <topic>` | Launch `sdd-explore` sub-agent |
| `/sdd-new <change>` | Run `sdd-explore` then `sdd-propose` (see `_shared/sdd-new/SKILL.md`) |
| `/sdd-continue [change]` | Create next missing artifact in dependency chain (see detection algorithm below) |
| `/sdd-ff [change]` | Run `sdd-propose` → `sdd-spec` → `sdd-design` → `sdd-tasks` — **skips exploration, warn the user** |
| `/sdd-propose <change>` | Launch `sdd-propose` sub-agent |
| `/sdd-spec <change>` | Launch `sdd-spec` sub-agent |
| `/sdd-design <change>` | Launch `sdd-design` sub-agent |
| `/sdd-tasks <change>` | Launch `sdd-tasks` sub-agent |
| `/sdd-apply [change]` | Launch `sdd-apply` sub-agent in batches |
| `/sdd-verify [change]` | Launch `sdd-verify` sub-agent |
| `/sdd-archive [change]` | Launch `sdd-archive` sub-agent |

---

## State Persistence (after every phase transition)

Write DAG state after each phase completes so that `/sdd-continue` and
post-compaction recovery work correctly:

- **engram mode:** `mem_save(topic_key: "sdd/{change}/state", content: "phase: {last-phase}\nartifacts: {...}")`
- **openspec mode:** write `openspec/changes/{change}/state.yaml` with current phase + artifact status
- **none mode:** not possible — warn the user that state will not survive context reset

---

## sdd-continue Detection Algorithm

When `/sdd-continue` is invoked, detect the next missing artifact:

**engram mode:** Search Engram for each artifact in order:
`proposal` → `spec` → `design` → `tasks` → `apply-progress` → `verify-report` → `archive-report`.
Launch the sub-agent for the first missing one. If `archive-report` exists, the change is closed.

**openspec mode:** Check file existence in order:
`proposal.md` → `specs/` (has files?) → `design.md` → `tasks.md` (all `[x]`?) → `verify-report.md` → `archive/` (archived?).
Launch the sub-agent for the first missing or incomplete artifact.

**none mode:** Ask the user which phase to run next.

---

## Dependency Graph

```
              proposal
                 │
    ┌────────────┴────────────┐
    ▼                         ▼
  specs                    design
    │                         │
    └────────────┬────────────┘
                 ▼
          tasks → apply → verify → archive
```

- `specs` and `design` both depend on `proposal` and **can run in parallel**.
  Parallel execution is a speed–quality tradeoff: design written without a
  finished spec may miss scenario constraints. Sequential (spec → design) produces
  stronger output when quality matters more than speed.
- `tasks` depends on both `specs` and `design`.

---

## Sub-Agent Launch Pattern

When launching a phase, require the sub-agent to read its SKILL.md first and
return a structured result with:

- `status`
- `executive_summary`
- `artifacts` (include IDs/paths)
- `next_recommended`
- `risks`

The install path for skill files depends on the tool. The tool-specific config
file must supply the resolved `{skills_dir}` when launching sub-agents.

---

## Shared Conventions (source of truth)

Keep tool configs lean. Do NOT inline full persistence and naming specs there.

Read the shared convention files installed alongside the skills under
`{skills_dir}/_shared/`:

| File | Purpose |
|------|---------|
| `engram-convention.md` | Artifact naming + two-step recovery protocol |
| `persistence-contract.md` | Mode behavior + state persistence/recovery rules |
| `openspec-convention.md` | File layout when mode is `openspec` |

---

## Recovery Rule

If SDD state is missing (e.g. after context compaction), recover from backend
state before continuing:

- **engram:** `mem_search(...)` then `mem_get_observation(...)`
- **openspec:** read `openspec/changes/*/state.yaml`  
- **none:** explain that state was not persisted; ask user which phase to resume

---

## SDD Suggestion Rule

For substantial features or refactors, proactively suggest SDD.
For small fixes or one-line questions, do not force SDD.
