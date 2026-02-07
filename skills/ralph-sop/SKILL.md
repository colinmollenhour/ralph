---
name: ralph-sop
description: "Generate implementation/ralph.json from an Agent SOP planning directory. Use when you have an existing planning directory with step/task files and need to create the Ralph execution tracker. Triggers on: ralph prep, ralph sop, prepare for ralph, create ralph.json, prep this plan, convert to ralph."
---

# Ralph SOP Prep

Generate `implementation/ralph.json` (the Ralph execution tracker) from an existing Agent SOP planning directory.

---

## The Job

1. Receive the path to a planning directory (e.g., `planning/lot-tracking-woo/`)
2. Scan `implementation/step*/task-*.code-task.md` to discover all tasks
3. Read each task file to extract the title from the `# Task: ` heading
4. Auto-assign IDs (`S{step}-T{task}`) and priorities based on step/task ordering
5. Read `summary.md` and `design/` to populate metadata fields
6. Generate `implementation/ralph.json` and `implementation/progress.md`

**Important:**
- This skill does NOT generate planning docs, research, design, or task files. It only creates the execution tracker from an existing planning directory.
- If `implementation/ralph.json` already exists, ask the user what to do (overwrite/cancel).
- All paths written to ralph.json are **relative to the project root**, not the planning directory.

---

## Expected Planning Directory Structure

The skill expects a directory following the Agent SOP convention:

```
<planning-dir>/
  summary.md                                    # Project overview (optional but recommended)
  rough-idea.md                                 # Raw concept (not used by Ralph directly)
  idea-honing.md                                # Q&A clarifications (not used by Ralph directly)
  research/                                     # Codebase research (referenced by task files)
    *.md
  design/                                       # Technical design docs
    detailed-design.md                          # Primary design document (optional but recommended)
  implementation/
    plan.md                                     # Implementation plan with step checklist
    step01/
      task-01-slug.code-task.md                 # Individual code task specifications
      task-02-slug.code-task.md
    step02/
      task-01-slug.code-task.md
    ...
```

### Task File Format (`.code-task.md`)

Each task file must have at minimum:

```markdown
# Task: {Title}

## Description
...

## Acceptance Criteria
1. **Criterion Name**
   - Given ...
   - When ...
   - Then ...
```

The task file is self-contained: it includes its own description, background, technical requirements, dependencies, implementation approach, acceptance criteria, and metadata. Ralph's prompt tells the agent to read this file directly.

---

## Scanning Logic

### Discovering Tasks

```bash
# Find all code-task files, sorted by step then task number
find <planning-dir>/implementation -name "*.code-task.md" -path "*/step*/*" | sort
```

### Extracting Task Metadata

For each `.code-task.md` file:

1. **Title**: Extract from the first `# Task: ` heading
   ```bash
   grep -m1 '^# Task:' file.md | sed 's/^# Task: //'
   ```

2. **Step number**: Extract from parent directory name (`step01` → `1`)

3. **Task number**: Extract from filename (`task-02-slug.code-task.md` → `2`)

4. **ID**: Format as `S{step}-T{task}` (e.g., `S01-T02`)
   - Zero-pad to 2 digits: `S01-T01`, `S14-T02`

5. **Priority**: Auto-assign sequentially starting at 1, ordered by step number then task number within step. This ensures tasks execute in dependency order.

### Detecting Summary and Design Docs

- **Summary**: Look for `summary.md` in the planning directory root
- **Design**: Look for `design/detailed-design.md` or the first `.md` file in `design/`
- Both are optional. If not found, omit from ralph.json (use `null`).

---

## Output Format: ralph.json

```json
{
  "planningDir": "planning/lot-tracking-woo",
  "project": "Lot Tracking for Work Order Output",
  "branchName": "ralph/lot-tracking-woo",
  "description": "Lot tracking through Kit To Stock assembly workflow",
  "summary": "planning/lot-tracking-woo/summary.md",
  "design": "planning/lot-tracking-woo/design/detailed-design.md",
  "tasks": [
    {
      "id": "S01-T01",
      "title": "Database Schema Changes",
      "source": "planning/lot-tracking-woo/implementation/step01/task-01-database-schema-changes.code-task.md",
      "step": 1,
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "S01-T02",
      "title": "Lot Number Generator",
      "source": "planning/lot-tracking-woo/implementation/step01/task-02-lot-number-generator.code-task.md",
      "step": 1,
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Field Rules

| Field | Required | Description |
|-------|----------|-------------|
| `planningDir` | Yes | Path to the planning directory (relative to project root) |
| `project` | Yes | Project name. Extract from `summary.md` heading or `plan.md` heading, or ask the user. |
| `branchName` | Yes | Git branch name. Default: `ralph/<planning-dir-basename>` (e.g., `ralph/lot-tracking-woo`) |
| `description` | Yes | Short description. Extract from summary or plan, or ask the user. |
| `summary` | No | Path to summary.md if it exists. `null` if not found. |
| `design` | No | Path to primary design document if it exists. `null` if not found. |
| `tasks[]` | Yes | Array of task objects, one per `.code-task.md` file |
| `tasks[].id` | Yes | Task ID in `S{step}-T{task}` format |
| `tasks[].title` | Yes | Extracted from `# Task:` heading in the code-task file |
| `tasks[].source` | Yes | Path to the `.code-task.md` file (relative to project root) |
| `tasks[].step` | Yes | Step number (integer) for grouping |
| `tasks[].priority` | Yes | Sequential integer starting at 1. Lower = execute first. |
| `tasks[].passes` | Yes | Boolean. Always `false` when generated. Set to `true` by Ralph during execution. |
| `tasks[].notes` | Yes | String. Empty when generated. Populated by Ralph during execution. |

---

## Output Format: progress.md

Initialize with this header:

```markdown
# Progress Log
Created: {current date/time}
Source: {path to planning directory}
---
```

---

## Branch Name Generation

Default branch name is derived from the planning directory's basename:

```
planning/lot-tracking-woo/  →  ralph/lot-tracking-woo
planning/auth-system/       →  ralph/auth-system
.sop/planning/my-feature/   →  ralph/my-feature
```

If the user specifies a different branch name, use that instead.

---

## Handling Existing Files

Before writing, check if `implementation/ralph.json` already exists:

```bash
if [ -f "<planning-dir>/implementation/ralph.json" ]; then
  # Ask user what to do
  echo "implementation/ralph.json already exists. Options:"
  echo "1. Overwrite (regenerate from task files)"
  echo "2. Cancel"
  # Wait for user input
fi
```

If overwriting, preserve `passes` and `notes` values for any tasks whose `source` path matches an existing entry. This allows re-scanning for new tasks while keeping progress on completed ones.

---

## Complete Example

**Input:** `planning/lot-tracking-woo/` with 14 steps, 19 tasks

**Scan discovers:**
```
step01/task-01-database-schema-changes.code-task.md     → S01-T01, priority 1
step01/task-02-lot-number-generator.code-task.md        → S01-T02, priority 2
step02/task-01-lot-type-admin-form-generator-field.code-task.md → S02-T01, priority 3
step03/task-01-bom-validation-kit-to-stock-lot-types.code-task.md → S03-T01, priority 4
step04/task-01-component-lot-data-and-block.code-task.md → S04-T01, priority 5
step04/task-02-component-lot-selection-template-and-js.code-task.md → S04-T02, priority 6
...
step14/task-01-e2e-cypress-kitting-with-lots.code-task.md → S14-T01, priority 18
step14/task-02-phpunit-integration-tests.code-task.md   → S14-T02, priority 19
```

**Output:** `planning/lot-tracking-woo/implementation/ralph.json` with 19 tasks.

**Output:** `planning/lot-tracking-woo/implementation/progress.md` with header.

---

## Checklist Before Saving

- [ ] Found the `implementation/` subdirectory with `step*/` directories
- [ ] Scanned all `.code-task.md` files and extracted titles
- [ ] Verified task files have `# Task:` headings
- [ ] Checked for existing `implementation/ralph.json`
- [ ] All paths relative to project root (not planning directory)
- [ ] Branch name follows convention or user override
- [ ] Priority ordering matches step/task dependency order
- [ ] `progress.md` initialized with header
- [ ] Reported total task count to user
