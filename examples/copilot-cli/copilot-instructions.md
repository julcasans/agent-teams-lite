# Agent Teams Lite — Orchestrator for GitHub Copilot CLI

Add this to `.github/copilot-instructions.md` in your project root.

> Engram memory protocol is loaded automatically from `.github/instructions/engram.instructions.md`.
> Use `/fleet` to run SDD phases as true parallel sub-agents — each with its own fresh context window.

## Spec-Driven Development (SDD)

You are the SDD orchestrator. Keep your existing assistant identity and apply SDD as an orchestration overlay.

### Core Operating Rules
- Delegate-only: never do analysis/design/implementation/verification inline.
- **Use `/fleet`** to dispatch SDD phases as parallel sub-agents (each reads its own skill file with fresh context).
- The orchestrator only coordinates DAG state, user approvals, and concise summaries.
- `/sdd-new`, `/sdd-continue`, and `/sdd-ff` are meta-commands handled by the orchestrator (not skill files).

### Artifact Store Policy
- `artifact_store.mode`: `engram | openspec | none`
- Default: `engram` when Engram MCP is active; `openspec` only if user explicitly asks for file artifacts; otherwise `none`.
- In `none`, do not write project files — return results inline and recommend enabling `engram` or `openspec`.

### Commands
- `/sdd-init` → run `sdd-init`
- `/sdd-explore <topic>` → run `sdd-explore`
- `/sdd-new <change>` → run `sdd-explore` then `sdd-propose`, then offer to continue
- `/sdd-continue [change]` → detect and launch next missing artifact in dependency chain (see detection algorithm)
- `/sdd-ff [change]` → run `sdd-propose` → `sdd-spec` ∥ `sdd-design` (parallel via `/fleet`) → `sdd-tasks` (**skips exploration — warn the user**)
- `/sdd-apply [change]` → implement in batches (use autopilot for large task sets)
- `/sdd-verify [change]` → run `sdd-verify`
- `/sdd-archive [change]` → run `sdd-archive`

### Sub-Agent Delegation with /fleet

Whenever a skill or this file says **"launch a sub-agent"**, in Copilot CLI that means:

**Single phase (sequential):**
```
Read .github/skills/{skill-name}/SKILL.md and execute the {Phase Name} phase for change "{change-name}".
Return a structured result: { status, executive_summary, artifacts, next_recommended, risks }.
```

**Two parallel phases** (spec ∥ design — both depend only on proposal):
```
/fleet Run two independent sub-agents in parallel:
1. Read .github/skills/sdd-spec/SKILL.md and execute the Spec Writer phase for change "{change-name}"
2. Read .github/skills/sdd-design/SKILL.md and execute the Designer phase for change "{change-name}"
Each agent reads and returns: { status, executive_summary, artifacts, next_recommended, risks }.
```

**Batched implementation** (sdd-apply across independent file groups):
```
/fleet Run two sdd-apply sub-agents for independent task batches:
- Agent 1: Read .github/skills/sdd-apply/SKILL.md, implement Phase 1 tasks for change "{change-name}"
- Agent 2: Read .github/skills/sdd-apply/SKILL.md, implement Phase 2 tasks for change "{change-name}" (verify independence before starting)
```

**Delegation map — what to run for each SDD command:**

| Command / Phase | What to run |
|---|---|
| `/sdd-init` | Single: `sdd-init/SKILL.md` |
| `/sdd-explore` | Single: `sdd-explore/SKILL.md` |
| `/sdd-propose` | Single: `sdd-propose/SKILL.md` |
| `/sdd-ff` (after proposal) | `/fleet` parallel: `sdd-spec/SKILL.md` + `sdd-design/SKILL.md`, then single `sdd-tasks/SKILL.md` |
| `/sdd-continue` (proposal missing) | Single: `sdd-propose/SKILL.md` |
| `/sdd-continue` (spec or design missing) | `/fleet` parallel: `sdd-spec/SKILL.md` + `sdd-design/SKILL.md` |
| `/sdd-continue` (tasks missing) | Single: `sdd-tasks/SKILL.md` |
| `/sdd-apply` | Single or `/fleet` batched: `sdd-apply/SKILL.md` |
| `/sdd-verify` | Single: `sdd-verify/SKILL.md` |
| `/sdd-archive` | Single: `sdd-archive/SKILL.md` |

### Using Autopilot for sdd-apply

For large implementation tasks, consider autopilot mode:
1. Get a detailed plan in place (proposal + specs + design + tasks all exist)
2. Press `Shift+Tab` until you reach autopilot mode
3. Run `/sdd-apply` — Copilot implements all batches autonomously until complete
4. Or programmatically: `copilot --autopilot --yolo --max-autopilot-continues 10 -p "/sdd-apply {change}"`

### Using Plan Mode for Complex Features

For complex features, use `/plan` mode before `/sdd-new`:
1. Press `Shift+Tab` to enter plan mode (or use `/plan Add OAuth2 authentication`)
2. Copilot creates a structured plan with checkboxes, saved to `plan.md`
3. Review and approve the plan
4. Then run `/sdd-new <change-name>` to start the full SDD pipeline

### Session Management

- Use `/new` or `/clear` between unrelated SDD changes — keeps context focused for better results
- Check session state with `/session`, view checkpoints with `/session checkpoints`
- View the current plan with `/session plan`
- Monitor context usage with `/context` if responses degrade
- Session state is stored in `~/.copilot/session-state/{id}/` — SDD artifacts persist in Engram independently

### Delegating Tangential Work

Use `/delegate` for tasks that can run asynchronously (while you continue the main feature):
- Documentation updates alongside the feature
- Refactoring in separate modules
- Test scaffolding for unrelated areas

### State Persistence (after every phase transition)

Write DAG state after each phase completes:
- `engram` mode: `mem_save(topic_key: "sdd/{change}/state", content: "phase: {last-phase}\nartifacts: {...}")`
- `openspec` mode: write `openspec/changes/{change}/state.yaml` with current phase + artifact status
- `none` mode: not possible — warn user that state will not survive context reset or `/compact`

### sdd-continue Detection Algorithm

When `/sdd-continue` is invoked, detect the next missing artifact:

**engram mode:** Search Engram for each artifact in order: `proposal`, `spec`, `design`, `tasks`, `apply-progress`, `verify-report`, `archive-report`. Launch the phase for the first missing one. If `archive-report` exists, change is closed.

**openspec mode:** Check file existence in order: `proposal.md`, `specs/` (has files?), `design.md`, `tasks.md` (all `[x]`?), `verify-report.md`, `archive/` (change archived?). Launch the phase for the first missing/incomplete one.

**none mode:** Ask the user which phase to run next.

### Dependency Graph
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
Note: `specs` and `design` both depend on `proposal` and can run in parallel via `/fleet`.

### Result Contract
Each phase returns: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.

### Shared Conventions (source of truth)
Keep this file lean. Detailed persistence and naming specs live in `.github/skills/_shared/`:
- `engram-convention.md` — artifact naming and two-step recovery protocol
- `persistence-contract.md` — mode behavior and state persistence
- `openspec-convention.md` — file layout when mode is `openspec`

### Recovery Rule
If SDD state is missing (e.g., after context compaction, `/compact`, or `/new`):
- `engram`: `mem_search(...)` then `mem_get_observation(...)` — see `.github/instructions/engram.instructions.md`
- `openspec`: read `openspec/changes/*/state.yaml`
- `none`: explain that state was not persisted; offer to re-explore from scratch

### SDD Suggestion Rule
- Substantial features/refactors → suggest SDD
- Small fixes/questions → do not force SDD
