# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding tools ([Amp](https://ampcode.com) by default) repeatedly until all PRD items are complete. Each iteration is a fresh instance of the agent with clean context to prevent context rot. Memory persists via git history, `progress.txt`, and `ralph.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Quick Start

1. **Create a PRD** using the `prd` skill:
   ```
   > Use the prd skill to create a PRD for user authentication
   ```
   This creates `plans/auth.md`

2. **Convert to Ralph format** using the `ralph` skill:
   ```
   > Use the ralph skill to convert plans/auth.md
   ```
   This creates `ralph/auth/ralph.json` and associated files

3. **Run Ralph:**
   ```bash
   ./ralph.sh ralph/auth
   ```
   Or just `./ralph.sh` for interactive chooser

4. **Monitor progress:**
   ```bash
   # See what Ralph will work on next
   ./ralph.sh ralph/auth --next-prompt
   
   # Check completion status
   jq '[.userStories[] | select(.passes == false)] | length' ralph/auth/ralph.json
   ```

## Directory Structure

```
project-root/
├── plans/                      # Your PRDs (created by prd skill)
│   ├── auth.md
│   └── dashboard.md
│
├── ralph/                      # Auto-generated execution directories
│   ├── auth/
│   │   ├── README.md          # Primary plan
│   │   ├── ralph.json         # Execution config with user stories
│   │   ├── progress.txt       # Iteration log with learnings
│   │   └── [domain].md        # Domain-specific plans (if split)
│   │
│   └── archive/               # Completed runs
│       └── 2026-01-14-auth/
│
└── ralph.sh                    # Main script
```

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Amp CLI](https://ampcode.com) (default)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
  - [OpenCode](https://github.com/AmruthPillai/OpenCode)
- Common shell utilities:
  - `jq` for JSON manipulation (`brew install jq` on macOS, `apt-get install jq` on Ubuntu)
  - `sponge` from moreutils for in-place file updates (`brew install moreutils` on macOS, `apt-get install moreutils` on Ubuntu)
- A git repository for your project

## Setup

### Option 1: Install globally (Recommended)

Download and install ralph.sh to your PATH:

```bash
# Download and install ralph.sh to your PATH
curl -o ~/.local/bin/ralph.sh https://raw.githubusercontent.com/snarktank/ralph/main/ralph.sh
chmod +x ~/.local/bin/ralph.sh

# Ensure ~/.local/bin is in PATH (add to ~/.bashrc, ~/.zshrc, or your shell's config)
export PATH="$HOME/.local/bin:$PATH"
```

### Option 2: Install skills

Copy the skills to your Amp or Claude config for use across all projects:

**For Amp:**
```bash
# From local clone
cp -r skills/prd ~/.config/amp/skills/
cp -r skills/ralph ~/.config/amp/skills/

# Or via curl (no clone needed)
mkdir -p ~/.config/amp/skills/{prd,ralph}
curl -o ~/.config/amp/skills/prd/SKILL.md https://raw.githubusercontent.com/snarktank/ralph/main/skills/prd/SKILL.md
curl -o ~/.config/amp/skills/ralph/SKILL.md https://raw.githubusercontent.com/snarktank/ralph/main/skills/ralph/SKILL.md
```

**For Claude Code:**
```bash
# From local clone
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/

# Or via curl (no clone needed)
mkdir -p ~/.claude/skills/{prd,ralph}
curl -o ~/.claude/skills/prd/SKILL.md https://raw.githubusercontent.com/snarktank/ralph/main/skills/prd/SKILL.md
curl -o ~/.claude/skills/ralph/SKILL.md https://raw.githubusercontent.com/snarktank/ralph/main/skills/ralph/SKILL.md
```

### Option 3: Copy to your project (Alternative)

If you prefer to keep ralph.sh in your project directory:

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/
chmod +x scripts/ralph/ralph.sh
```

### Configure Amp auto-handoff (recommended)

Add to `~/.config/amp/settings.json`:

```json
{
  "amp.experimental.autoHandoff": { "context": 90 }
}
```

This enables automatic handoff when context fills up, allowing Ralph to handle large stories that exceed a single context window.

## Workflow

### 1. Create a PRD

Use the PRD skill to generate a detailed requirements document:

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `plans/[feature-name].md`.

### 2. Convert PRD to Ralph format

Use the Ralph skill to convert the markdown PRD to a Ralph execution directory:

```
Load the ralph skill and convert plans/[feature-name].md
```

This creates `ralph/[feature-name]/` with:
- `README.md` - Primary plan (copy of source or high-level overview if split)
- `ralph.json` - User stories structured for autonomous execution
- `progress.txt` - Iteration log initialized with header
- `[domain].md` files - Domain-specific plans (only if PRD was large and split)

### 3. Run Ralph

```bash
# Interactive chooser (if multiple projects)
./ralph.sh

# Run specific project
./ralph.sh ralph/auth

# With options
./ralph.sh ralph/auth -n 10              # Max 10 iterations
./ralph.sh ralph/auth --tool claude      # Use Claude Code
./ralph.sh ralph/auth --tool opencode    # Use OpenCode
./ralph.sh ralph/auth --next-prompt      # Debug: see prompt without running

# Stop a running Ralph
./ralph.sh --stop ralph/auth
```

Run `ralph.sh --help` for all options.

Ralph will:
1. Create a feature branch (from `branchName` in ralph.json)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Update `ralph.json` to mark story as `passes: true`
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations reached

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances |
| `plans/` | Source PRDs (user-created, read-only by Ralph) |
| `ralph/[feature]/` | Execution directories (auto-generated) |
| `ralph/[feature]/ralph.json` | User stories with `passes` status (the task list) |
| `ralph/[feature]/progress.txt` | Append-only learnings for future iterations |
| `skills/prd/` | Skill for generating PRDs |
| `skills/ralph/` | Skill for converting PRDs to execution directories |
| `flowchart/` | Interactive visualization of how Ralph works |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

The `flowchart/` directory contains the source code. To run locally:

```bash
cd flowchart
npm install
npm run dev
```

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new AI instance** (Amp, Claude Code, or OpenCode) with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `ralph.json` (which stories are done)

### Token Efficiency

Ralph is designed to minimize token usage per iteration:
- Never read full `ralph.json` - use `jq` queries
- Load only relevant sections of `progress.txt`
- Story-specific domain files only loaded when needed
- Expected overhead: ~1350-3000 tokens vs ~8000-15000 in naive approach

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### AGENTS.md Updates Are Critical

After each iteration, Ralph updates the relevant `AGENTS.md` files with learnings. This is key because AI coding tools automatically read these files, so future iterations (and future human developers) benefit from discovered patterns, gotchas, and conventions.

Examples of what to add to AGENTS.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Debugging

Use `--next-prompt` to see exactly what context Ralph loads:
```bash
./ralph.sh ralph/auth --next-prompt
```

This shows the full prompt, plan files, and progress context without invoking the LLM.

Check current state:

```bash
# See which stories are done
jq '.userStories[] | {id, title, passes}' ralph/auth/ralph.json

# See learnings from previous iterations
cat ralph/auth/progress.txt

# Check git history
git log --oneline -10
```

## Customizing the Prompt

Ralph looks for prompts in this order:
1. `--custom-prompt <file>` - Explicit flag takes highest priority
2. `[ralph-dir]/.agents/ralph.md` - Project-local template (if exists)
3. Embedded default prompt

To customize for your project:
1. Run `ralph.sh --eject-prompt ralph/auth` which will create `ralph/auth/.agents/ralph.md`
2. Modify it for your needs  
3. Ralph will automatically use it

### Post-Completion Cleanup

When all stories are complete, Ralph automatically removes working files from git (but keeps them on disk) in a final commit.

**This cleanup commit can be reverted:**
```bash
# Undo the cleanup
git revert HEAD

# Recover the files
git checkout HEAD~1 -- ralph/auth/
```

**To disable cleanup:** Create a custom prompt template without the cleanup instructions in the Stop Condition section.

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `ralph/archive/YYYY-MM-DD-feature-name/`.

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Amp documentation](https://ampcode.com/manual)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
