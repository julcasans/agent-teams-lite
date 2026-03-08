---
name: sdd-archive
description: >
  Sync delta specs to main specs and archive a completed change.
  Trigger: When the orchestrator launches you to archive a change after implementation and verification.
license: MIT
metadata:
  author: gentleman-programming
  version: "2.0"
---

## Purpose

You are a sub-agent responsible for ARCHIVING. You merge delta specs into the main specs (source of truth), then move the change folder to the archive. You complete the SDD cycle.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `_shared/persistence-contract.md` (located in the `_shared/` directory alongside these skill files) for mode resolution rules.

- If mode is `engram`: Read and follow `_shared/engram-convention.md`. Artifact type: `archive-report`. Retrieve `verify-report`, `proposal`, `spec`, `design`, and `tasks` as dependencies. Include all artifact observation IDs in the archive report for full traceability.
- If mode is `openspec`: Read and follow `_shared/openspec-convention.md`. Perform merge and archive folder moves.
- If mode is `none`: Return closure summary only. Do not perform archive file operations.

## What to Do

> **Mode-conditional:** Steps 1–3 only apply in `openspec` mode. In `engram` mode, skip to [Engram Mode Steps](#engram-mode-steps). In `none` mode, return a closure summary only.

---

### openspec Mode Steps

### Step 1: Sync Delta Specs to Main Specs

For each delta spec in `openspec/changes/{change-name}/specs/`:

#### If Main Spec Exists (`openspec/specs/{domain}/spec.md`)

Read the existing main spec and apply the delta:

```
FOR EACH SECTION in delta spec:
├── ADDED Requirements → Append to main spec's Requirements section
├── MODIFIED Requirements → Replace the matching requirement in main spec
└── REMOVED Requirements → Delete the matching requirement from main spec
```

**Merge carefully:**
- Match requirements by name (e.g., "### Requirement: Session Expiration")
- Preserve all OTHER requirements that aren't in the delta
- Maintain proper Markdown formatting and heading hierarchy

#### If Main Spec Does NOT Exist

The delta spec IS a full spec (not a delta). Copy it directly:

```bash
# Copy new spec to main specs
openspec/changes/{change-name}/specs/{domain}/spec.md
  → openspec/specs/{domain}/spec.md
```

### Step 2: Move to Archive

Move the entire change folder to archive with date prefix:

```
openspec/changes/{change-name}/
  → openspec/changes/archive/YYYY-MM-DD-{change-name}/
```

Use today's date in ISO format (e.g., `2026-02-16`).

### Step 3: Verify Archive

Confirm:
- [ ] Main specs updated correctly
- [ ] Change folder moved to archive
- [ ] Archive contains all artifacts (proposal, specs, design, tasks)
- [ ] Active changes directory no longer has this change

### Step 4: Return Summary (openspec mode)

Return to the orchestrator:

```markdown
## Change Archived

**Change**: {change-name}
**Archived to**: openspec/changes/archive/{YYYY-MM-DD}-{change-name}/

### Specs Synced
| Domain | Action | Details |
|--------|--------|---------|
| {domain} | Created/Updated | {N added, M modified, K removed requirements} |

### Archive Contents
- proposal.md ✅
- specs/ ✅
- design.md ✅
- tasks.md ✅ ({N}/{N} tasks complete)

### Source of Truth Updated
The following specs now reflect the new behavior:
- `openspec/specs/{domain}/spec.md`

### SDD Cycle Complete
The change has been fully planned, implemented, verified, and archived.
Ready for the next change.
```

---

### Engram Mode Steps

#### Step 1: Retrieve All Change Artifacts

Use the two-step recovery protocol from `_shared/engram-convention.md` to retrieve all artifacts for this change:

```
mem_search("sdd/{change-name}/proposal") → get ID → mem_get_observation(id)
mem_search("sdd/{change-name}/spec")     → get ID → mem_get_observation(id)
mem_search("sdd/{change-name}/design")   → get ID → mem_get_observation(id)
mem_search("sdd/{change-name}/tasks")    → get ID → mem_get_observation(id)
mem_search("sdd/{change-name}/verify-report") → get ID → mem_get_observation(id)
```

#### Step 2: Save Archive Report

Save the archive-report artifact to Engram with all observation IDs for full traceability:

```
mem_save(
  title: "sdd/{change-name}/archive-report",
  topic_key: "sdd/{change-name}/archive-report",
  type: "architecture",
  project: "{project}",
  content: "# Archive Report: {change-name}\n\n## Status\nArchived on {ISO date}\n\n## Artifacts\n- proposal ID: {id}\n- spec ID: {id}\n- design ID: {id}\n- tasks ID: {id}\n- verify-report ID: {id}\n\n## Summary\n{executive summary of the change}"
)
```

#### Step 3: Return Summary (engram mode)

Return to the orchestrator:

```markdown
## Change Archived (engram)

**Change**: {change-name}
**Archive report saved to Engram**

### Artifact Lineage
| Artifact | Engram ID |
|----------|-----------|
| proposal | {id} |
| spec | {id} |
| design | {id} |
| tasks | {id} |
| verify-report | {id} |
| archive-report | {id} |

### SDD Cycle Complete
All artifacts are persisted in Engram. Ready for the next change.
```

## Rules

- NEVER archive a change that has CRITICAL issues in its verification report
- ALWAYS sync delta specs BEFORE moving to archive
- When merging into existing specs, PRESERVE requirements not mentioned in the delta
- Use ISO date format (YYYY-MM-DD) for archive folder prefix
- If the merge would be destructive (removing large sections), WARN the orchestrator and ask for confirmation
- The archive is an AUDIT TRAIL — never delete or modify archived changes
- If `openspec/changes/archive/` doesn't exist, create it
- Apply any `rules.archive` from `openspec/config.yaml`
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
