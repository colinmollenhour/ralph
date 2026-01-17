# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding agents repeatedly until all project items are complete.

Each iteration spawns a fresh session with clean context to prevent context rot. Memory persists via git history and simple, readable files on disk.

> [!NOTE]  
> This is a fork of Ryan Carson's [Ralph](https://github.com/snarktank/ralph) which he wished to preserve as a simpler script.
> 
> Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).
> 
> [Read Ryan's in-depth article on how he uses Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Added Features

- Redesigned skills workflows and file locations
- Run from anywhere, prompt embedded in the script
- Added support for OpenCode and Claude Code (in addition to Amp)
- Prettier output with process PID, CPU %, Memory, Remote Port, task wall time, total wall time
- Automatic worktree creation, no manually moving plans to worktrees
  - Commits bookkeeping files for the ability to rewind, but rewrites all commits once complete to keep commits clean
- More efficient bookkeeping (jq - much more efficient than the LLM)
- Adds back the original plan context, either in full or in part (split up if it's large)
  - The original plan context was "lost" and Ralph was only getting the basic user story and acceptance criteria but no commentary

## Quick Start

1. **Create a plan/PRD** (optional - use `ralph-prd` skill or write manually):
   ```
   > Use the ralph-prd skill to create a PRD for user authentication
   ```
   This creates `plans/auth.md`
   
   Alternatively, you can write a PRD manually in `plans/` directory.

2. **Convert your plans to Ralph format** using the `ralph-prep` skill (**REQUIRED**):
   ```
   > Use the ralph-prep skill to convert plans/auth.md
   ```
   This creates `ralph/auth/ralph.json` and associated files
   
   **Note:** `ralph-prep` works with any PRD file (created by `ralph-prd` or written manually).

3. **Run Ralph: (example plan called "auth")**
   ```bash
   ./ralph.sh ralph/auth
   ```
   Or just `./ralph.sh` to use the first incomplete plan if there is only one plan or present an interactive chooser if there is more than one.

4. **Monitor progress:**
   ```bash
   # See Ralph's progress
   ./ralph.sh ralph/auth --status

   # See the next prompt Ralph will use - no magic!
   ./ralph.sh ralph/auth --next-prompt
   ```

## When to Use ralph-prd

The `ralph-prd` skill is **optional** but useful for:
- **Complex features** requiring detailed acceptance criteria
- **Large projects** where structured planning helps
- **Teams** who want consistent PRD format across features

For simple features, you can write PRDs manually in the `plans/` directory.

> [!TIP]
> The **only required skill** is `ralph-prep`, which converts any plan or PRD (manual or generated) into Ralph's execution format.

## Directory Structure

```
project-root/
├── plans/                      # Your PRDs (created by ralph-prd skill or manually - can live anywhere, actually)
│   ├── auth.md                 # These files will not be modified by Ralph
│   └── dashboard.md
│
└── ralph/                      # Auto-generated execution directories
    ├── auth/                   # Project slug in this example is "auth", derived from plans/auth.md
    │   ├── README.md           # Primary plan description, either a simple copy of your plan or a shortened high-level view of it if split
    │   ├── ralph.json          # Execution config and status with user stories
    │   ├── progress.txt        # Simple iteration history log
    │   ├── AGENTS.md           # Learnings from each iteration
    │   └── [domain].md         # Domain-specific plans (if auto-split by the ralph-prep step)
    │
    └── archive/                # Completed runs
        └── 2026-01-14-auth/
```

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Amp CLI](https://ampcode.com) (default)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
  - [OpenCode](https://github.com/AmruthPillai/OpenCode)
- Common shell utilities:
  - `jq` for JSON manipulation (`brew install jq` on macOS, `apt-get install jq` on Ubuntu)
  - `git` of course
  - `sed`, etc.
- A git repository for your project

## Setup

### Step 1: Install `ralph.sh`

Download and install `ralph.sh` to your `PATH` for easy access, although it can be invoked from anywhere.

```bash
curl -o ~/.local/bin/ralph.sh https://raw.githubusercontent.com/colinmollenhour/ralph/main/ralph.sh
chmod +x ~/.local/bin/ralph.sh

# Ensure ~/.local/bin is in PATH (add to ~/.bashrc, ~/.zshrc, or your shell's config)
export PATH="$HOME/.local/bin:$PATH"
```

### Step 2: Install skills

Copy the [Agent Skills](https://agentskills.io/) to your Amp or Claude config for use across all projects:

**For Amp:**
```bash
# From local clone
cp -r skills/ralph-prd ~/.config/amp/skills/
cp -r skills/ralph-prep ~/.config/amp/skills/

# Or via curl (no clone needed)
mkdir -p ~/.config/amp/skills/{ralph-prd,ralph-prep}
curl -o ~/.config/amp/skills/ralph-prd/SKILL.md https://raw.githubusercontent.com/colinmollenhour/ralph/main/skills/ralph-prd/SKILL.md
curl -o ~/.config/amp/skills/ralph-prep/SKILL.md https://raw.githubusercontent.com/colinmollenhour/ralph/main/skills/ralph-prep/SKILL.md
```

**For Claude Code and OpenCode:**
```bash
# From local clone
cp -r skills/ralph-prd ~/.claude/skills/
cp -r skills/ralph-prep ~/.claude/skills/

# Or via curl (no clone needed)
mkdir -p ~/.claude/skills/{ralph-prd,ralph-prep}
curl -o ~/.claude/skills/ralph-prd/SKILL.md https://raw.githubusercontent.com/colinmollenhour/ralph/main/skills/ralph-prd/SKILL.md
curl -o ~/.claude/skills/ralph-prep/SKILL.md https://raw.githubusercontent.com/colinmollenhour/ralph/main/skills/ralph-prep/SKILL.md
```

## Workflow

### Step 1. Create a PRD

Ideally you should have a solid list of user stories and acceptance criteria. The `ralph-prd` skill will generate these for you from
your existing plan files or from your session context. This isn't strictly required, but this system is designed to have user stories
and acceptance criteria.

```
Use the ralph-prd skill to create a PRD for [your feature description/files]
```

The skill saves output to `plans/PRD-[feature-name].md`.

### Step 2. Convert your plan/PRD to Ralph format (**REQUIRED**)

Use the `ralph-prep` skill to convert the markdown PRD to a Ralph execution directory:

```
Use the ralph-prep skill to prepare plans/PRD-[feature-name].md
```

This creates `ralph/[feature-name]/` with:
- `README.md` - Primary plan (copy of source or high-level overview if split)
- `ralph.json` - User stories structured for autonomous execution
- `progress.txt` - Iteration log initialized with header
- `[domain].md` files - Domain-specific plans (only if PRD was large and split)

### Step 3. Run Ralph

You are now ready to run Ralph. If you have just one plan simply run `ralph.sh` and watch it go!

```bash
# Run specific project
ralph.sh ralph/auth

# With options (can be combined)
ralph.sh ralph/auth -n 10              # Max 10 iterations (default 20)
ralph.sh ralph/auth --tool claude      # Use Claude Code
ralph.sh ralph/auth --tool opencode    # Use OpenCode
ralph.sh ralph/auth --next-prompt      # Inspect the next prompt without executing the agent
ralph.sh ralph/auth --learn            # Normal execution + learn on final iteration
ralph.sh ralph/auth --learn-now        # Just run the learn prompt to absorb the AGENTS.md into your main AGENTS.md
ralph.sh ralph/auth --worktree         # Create a git worktree for branch "ralph/auth" at `.worktrees/auth` for execution in a clean environment

# Stop a running Ralph gracefully (let it finish the current task before stopping)
ralph.sh ralph/auth --stop
```

Run `ralph.sh --help` for all options.

Ralph will:
1. Create a feature branch (from `branchName` in `ralph.json` - and a worktree if `--worktree` is used)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (lint, typecheck, tests)
5. Append learnings to the `ralph/[feature]/AGENTS.md` file
6. Update `ralph.json` to mark story as `passes: true`
7. Commit all changed files including the Ralph files
8. Repeat from step 2 until all stories pass or max iterations reached (the loop)
9. Remove all Ralph files in the last commit (easy to recover)

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances |
| `plans/` | Source PRDs (user-created, read-only by Ralph) |
| `ralph/[feature]/` | Execution directories (auto-generated) |
| `ralph/[feature]/ralph.json` | User stories with `passes` status (the task list) |
| `ralph/[feature]/progress.txt` | Simple iteration history |
| `ralph/[feature]/AGENTS.md` | Learnings for future iterations (created on first task) |
| `skills/ralph-prd/` | Optional skill for generating PRDs |
| `skills/ralph-prep/` | **REQUIRED** skill for converting PRDs to execution directories |
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
- `AGENTS.md` (project-specific learnings)
- `progress.txt` (history log)
- `ralph.json` (which stories are done)

### Token Efficiency

Ralph pre-computes all context and injects it directly into the prompt:
- Story details, acceptance criteria, and commands are pre-computed
- Learnings from `AGENTS.md` are included in the prompt
- Agents don't need to read `ralph.json` (although sometimes they do anyway)
- Expected overhead: ~1800-3500 tokens vs ~8000-15000 in naive approach

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

### Learnings Storage

Each Ralph project has its own `AGENTS.md` file (created automatically). Agents append learnings here during execution.

To absorb learnings into the project root `./AGENTS.md`:
```bash
./ralph.sh ralph/auth --learn      # Absorb after all stories complete
./ralph.sh ralph/auth --learn-now  # or do it later after review
```

Examples of what is added to `AGENTS.md`:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Feedback Loops

Ralph only works if there are solid feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser
skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Inspection/Debugging

Use `--next-prompt` to see exactly what context Ralph loads:
```bash
./ralph.sh ralph/auth --next-prompt
```

This shows the full prompt, plan files, and progress context without invoking the agent.

Check current state:

```bash
# See which stories are done
ralph.sh ralph/auth --status

# See learnings from previous iterations
cat ralph/auth/progress.txt

# Check git history
git log --oneline -10
```

## Customizing the Prompt

The prompt should work well for general purposes but you can provide your own if your project needs different instructions like special
git commit message formats or automatically creating pull requests, running code review tools, etc.

Ralph looks for prompts in this order:
1. `--custom-prompt <file>` - Explicit flag takes highest priority
2. `[ralph-dir]/.agents/ralph.md` - Project-local template (if exists)
3. Embedded default prompt

To customize for your project:
1. Run `ralph.sh --eject-prompt` which will create `.agents/ralph.md` in your project directory.
2. Modify it for your needs, probably add it to your repo.
3. Ralph will automatically use it over the embedded one for this project.

### Post-Completion Cleanup

When all stories are complete, Ralph automatically removes working files in a final commit, but of course they can be recovered.

```bash
# Revert the last commit
git reset --hard HEAD^

# Recover the files without changing history
git checkout HEAD~1 -- ralph/auth/
```

**To disable cleanup:** Create a custom prompt template without the cleanup instructions in the Stop Condition section.

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `ralph/archive/YYYY-MM-DD-feature-name/`.

## Testing with test-project

A minimal test project is included to try Ralph without affecting your own codebase.

```bash
cd test-project

# Reset to initial state (creates git repo if needed - can do this multiple times)
./reset.sh

# Preview what Ralph will do
../ralph.sh --next-prompt ralph/add-math-functions

# Run Ralph (requires amp, claude, or opencode to be installed)
../ralph.sh ralph/add-math-functions --tool amp
# or
../ralph.sh ralph/add-math-functions --tool claude
# or
../ralph.sh ralph/add-math-functions --tool opencode
```

The test project has 5 simple user stories that add math functions to `src/math.ts`. Each story is small enough to complete in a single iteration, making it ideal for testing Ralph's behavior.

## References

- [Ryan Carson's original script](https://github.com/snarktank/ralph) which he wished to preserve as a simple script.
- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Amp documentation](https://ampcode.com/manual)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
