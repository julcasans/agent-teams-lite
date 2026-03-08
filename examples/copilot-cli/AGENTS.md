# SDD Orchestrator — Agent Teams Lite

This project uses **Agent Teams Lite** for Spec-Driven Development (SDD).

This file is auto-discovered by GitHub Copilot CLI (`AGENTS.md` in git root). Alternatively, paste the full orchestrator instructions from `examples/copilot-cli/copilot-instructions.md` into `.github/copilot-instructions.md`.

> Engram memory: `.github/instructions/engram.instructions.md` is auto-loaded by Copilot CLI for persistent SDD state across sessions.

## Quick Start

```
/sdd-init             — detect stack, initialize persistence
/sdd-new <name>       — start a new feature or change
/sdd-continue         — resume from the last completed phase
/sdd-apply            — implement current batch of tasks
/sdd-verify           — validate against specs
/sdd-archive          — close and archive the change
```

## Key Copilot CLI Features for SDD

- **`/fleet`** — run spec and design phases in parallel (true sub-agent delegation with fresh context)
- **Autopilot mode** (`Shift+Tab`) — let Copilot implement all sdd-apply batches autonomously
- **`/plan` mode** (`Shift+Tab`) — create a structured plan before starting `/sdd-new`
- **`/delegate`** — offload tangential work (docs, refactors) while you continue the main feature
- **`/new`** — start a fresh session between unrelated changes for better focus

## Sub-Agent Delegation — What "launch a sub-agent" means in Copilot CLI

When the orchestrator or a skill says "launch a sub-agent", use one of these patterns:

**Single phase:**
```
Read .github/skills/{skill-name}/SKILL.md and execute the {Phase} phase for change "{name}".
Return: { status, executive_summary, artifacts, next_recommended, risks }.
```

**Two parallel phases (`/fleet`):**
```
/fleet Run two independent sub-agents in parallel:
1. Read .github/skills/sdd-spec/SKILL.md and execute the Spec Writer phase for change "{name}"
2. Read .github/skills/sdd-design/SKILL.md and execute the Designer phase for change "{name}"
```

## Skill Files

All SDD skill files live in `.github/skills/`:

| Skill | What it does |
|-------|-------------|
| `sdd-init/SKILL.md` | Detect stack, bootstrap persistence |
| `sdd-explore/SKILL.md` | Analyze codebase, compare approaches |
| `sdd-propose/SKILL.md` | Create proposal with intent + scope |
| `sdd-spec/SKILL.md` | Write delta specs (Given/When/Then) |
| `sdd-design/SKILL.md` | Architecture decisions and rationale |
| `sdd-tasks/SKILL.md` | Phased implementation checklist |
| `sdd-apply/SKILL.md` | Write code, check off tasks |
| `sdd-verify/SKILL.md` | Run tests, compliance matrix |
| `sdd-archive/SKILL.md` | Merge delta specs, close change |

Shared conventions in `.github/skills/_shared/`:
- `persistence-contract.md` — engram / openspec / none mode rules
- `engram-convention.md` — deterministic artifact naming + recovery
- `openspec-convention.md` — file layout for openspec mode
