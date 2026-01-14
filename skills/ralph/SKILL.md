---
name: ralph
description: "Convert PRDs to ralph.json format for the Ralph autonomous agent system. Use when you have an existing PRD and need to convert it to Ralph's JSON format. Triggers on: convert this prd, turn this into ralph format, create ralph.json from this, ralph json."
---

# Ralph PRD Converter

Converts PRDs from plans/ into self-contained Ralph execution directories.

---

## The Job

1. Read the source PRD (e.g., `plans/auth.md`)
2. Analyze size: count chars, divide by 4 for rough token estimate
3. Decide: Split or keep as single file?
   - If > 3500 tokens OR > 300 lines: Split into domains
   - Otherwise: Single README.md (copy of source)
4. Create directory: `ralph/[basename]/` (basename = source filename without .md)
5. Write files:
   - `README.md` - Primary plan
   - `ralph.json` - Execution config
   - `progress.txt` - Initialized with header
   - `[domain].md` files (if splitting)

**Important:** 
- Directory name comes from source basename: `plans/auth.md` -> `ralph/auth/`
- If `ralph/auth/` already exists, ask user for instructions (overwrite/rename/cancel)
- All paths in ralph.json are relative to project root

---

## Decision: Split or Single File?

```bash
# Calculate rough token count
CHARS=$(wc -c < plans/auth.md)
TOKENS=$((CHARS / 4))
LINES=$(wc -l < plans/auth.md)

# Decision logic
if [[ $TOKENS -gt 3500 ]] || [[ $LINES -gt 300 ]]; then
  SPLIT=true
else
  SPLIT=false
fi
```

### If NOT splitting:
- Copy source PRD to `ralph/auth/README.md`:
  ```bash
  cp plans/auth.md ralph/auth/README.md
  ```
- No story-level `source` fields in ralph.json
- Agents read README.md + story JSON only

### If splitting:
- Create high-level overview in `ralph/auth/README.md`
- Create domain files: `ralph/auth/database.md`, etc.
- Add `source` field to each story pointing to its domain file

---

## Domain Auto-Detection (for splits)

Group user stories by common domains using keyword matching:

**Database/Schema** 
- Keywords: table, column, migration, schema, database, index, model, entity
- Example: "Add users table", "Create index on email"

**Backend/API**
- Keywords: endpoint, route, API, server action, middleware, handler, controller
- Example: "Create login endpoint", "Add auth middleware"

**UI Components**
- Keywords: component, form, button, modal, page, layout, view, screen
- Example: "Create login form", "Add dashboard layout"

**Business Logic**
- Keywords: service, util, helper, calculation, validation, transform, process
- Example: "Add password hashing", "Implement JWT generation"

**Testing**
- Keywords: test, spec, e2e, integration, unit, fixture
- Example: "Add login tests", "E2E authentication flow"

**Infrastructure**
- Keywords: deploy, build, config, docker, CI, environment
- Example: "Add deployment script", "Configure auth env vars"

### Splitting Strategy

1. **Analyze all user stories** - Extract title + description
2. **Keyword match** - Assign each story to a domain
3. **Consolidate** - Aim for 2-5 domains (not too fragmented)
4. **General domain fallback** - Stories that don't match -> "general.md"

### Creating Domain Files

Each domain file should contain:
- Domain-specific requirements extracted from PRD
- Details relevant to that domain's stories
- Technical notes, constraints, patterns for that domain

**Example: `ralph/auth/database.md`**
```markdown
# Authentication - Database Domain

## Schema Requirements
[Extract database-related requirements from original PRD]

## Migration Strategy
[Extract migration notes]

## User Stories
This domain covers:
- US-001: Create users table
- US-002: Add sessions table
```

---

## Output Format: ralph.json

```json
{
  "source": "ralph/auth/README.md",
  "project": "[Project Name from PRD]",
  "branchName": "ralph/[feature-kebab-case]",
  "description": "[Feature description from PRD title/intro]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "source": "ralph/auth/database.md",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

**Field rules:**
- `source` (root level): Always present, points to `ralph/[feature]/README.md`
- `source` (story level): Optional, only present if PRD was split
- All paths relative to project root
- Story priority based on dependency order

---

## Output Format: progress.txt

Initialize with this header:

```
# Ralph Progress Log
Started: [YYYY-MM-DD HH:MM]
Source PRD: ralph/auth/README.md
---

## Codebase Patterns
(Agents will populate this section with reusable learnings)

## Iteration History
```

---

## Handling Existing Directories

Before creating `ralph/auth/`, check if it exists:

```bash
if [ -d "ralph/auth" ]; then
  # Ask user what to do
  echo "ralph/auth/ already exists. Options:"
  echo "1. Overwrite (delete and recreate)"
  echo "2. Create ralph/auth-2/ instead"
  echo "3. Cancel"
  # Wait for user input
fi
```

---

## Complete Examples

### Example 1: Small PRD (No Split)

**Input:** `plans/bugfix.md` (100 lines, ~400 tokens)

**Output:** `ralph/bugfix/`
```
ralph/bugfix/
├── README.md          # Copy of plans/bugfix.md
├── ralph.json         # No story-level source fields
└── progress.txt       # Initialized header
```

**ralph.json:**
```json
{
  "source": "ralph/bugfix/README.md",
  "userStories": [
    {
      "id": "US-001",
      "title": "Fix button color",
      "description": "...",
      "acceptanceCriteria": ["..."],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Example 2: Large PRD (Split)

**Input:** `plans/auth.md` (500 lines, ~2000 tokens)

**Analysis:** 7 user stories grouped into 3 domains

**Output:** `ralph/auth/`
```
ralph/auth/
├── README.md          # High-level overview
├── ralph.json         # Story sources point to domains
├── progress.txt       # Initialized
├── database.md        # US-001, US-002
├── ui-components.md   # US-003, US-004, US-005
└── api-endpoints.md   # US-006, US-007
```

**README.md:**
```markdown
# User Authentication System

## Overview
Complete email/password authentication with JWT sessions.

## Architecture
- Database: PostgreSQL + Drizzle ORM
- Backend: JWT tokens in httpOnly cookies
- Frontend: React with Nuxt UI components

## Implementation Domains

This feature is organized into 3 domains:

1. **Database** (US-001, US-002) - User schema, sessions table
2. **UI Components** (US-003-005) - Login form, signup form, session display
3. **API Endpoints** (US-006, US-007) - Auth routes, middleware

See domain-specific files for detailed requirements.
```

**ralph.json:**
```json
{
  "source": "ralph/auth/README.md",
  "project": "MyApp",
  "branchName": "ralph/auth",
  "description": "User Authentication System",
  "userStories": [
    {
      "id": "US-001",
      "title": "Create users table",
      "source": "ralph/auth/database.md",
      "description": "...",
      "acceptanceCriteria": ["..."],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-003",
      "title": "Create login form",
      "source": "ralph/auth/ui-components.md",
      "description": "...",
      "acceptanceCriteria": ["..."],
      "priority": 3,
      "passes": false,
      "notes": ""
    }
  ]
}
```

---

## Checklist Before Saving

- [ ] Source file basename used for directory name
- [ ] Checked for existing ralph/[feature]/ directory
- [ ] Token count calculated (chars / 4)
- [ ] Split decision made based on size
- [ ] If split: All stories assigned to domains
- [ ] If split: README.md has high-level overview
- [ ] ralph.json source paths relative to project root
- [ ] progress.txt initialized with header
- [ ] All user stories have verifiable acceptance criteria
- [ ] Stories ordered by dependency (schema -> backend -> UI)
