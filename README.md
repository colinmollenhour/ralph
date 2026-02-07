# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding agents repeatedly until all project tasks are complete.

Each iteration spawns a fresh session with clean context to prevent context rot. Memory persists via git history and simple, readable files on disk.

> [!NOTE]  
> This is a fork of Ryan Carson's [Ralph](https://github.com/snarktank/ralph) which he wished to preserve as a simpler script.
> 
> Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).
> 
> [Read Ryan's in-depth article on how he uses Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Added Features

- Redesigned skills workflows and file locations
- Agent SOP-style planning directories with `.code-task.md` specification files
- Run from anywhere, prompt embedded in the script
- Added support for OpenCode and Claude Code (in addition to Amp)
- Prettier output with process PID, CPU %, Memory, Remote Port, task wall time, total wall time
- Automatic worktree creation, no manually moving plans to worktrees
  - Commits bookkeeping files for the ability to rewind, but rewrites all commits once complete to keep commits clean
- More efficient bookkeeping (jq - much more efficient than the LLM)
- Task specs are self-contained with description, requirements, acceptance criteria, and references to design/research docs

## Quick Start

1. **Create a planning directory** with task specifications:
   ```
   planning/my-feature/
   ├── summary.md                    # Project overview
   ├── design/detailed-design.md     # Technical design (optional)
   └── implementation/
       ├── plan.md                   # Step checklist
       ├── step01/
       │   ├── task-01-foo.code-task.md
       │   └── task-02-bar.code-task.md
       └── step02/
           └── task-01-baz.code-task.md
   ```

   You can create these manually or use Agent SOP tooling (pdd, code-task-generator).

2. **Generate the Ralph execution tracker** using the `ralph-sop` skill:
   ```
   > Use the ralph-sop skill to prepare planning/my-feature for Ralph
   ```
   This creates `planning/my-feature/implementation/ralph.json` and `progress.md`.

3. **Run Ralph:**
   ```bash
   ./ralph.sh planning/my-feature
   ```
   Or just `./ralph.sh` to use the first incomplete project if there is only one or present an interactive chooser if there are more.

4. **Monitor progress:**
   ```bash
   # See Ralph's progress
   ./ralph.sh planning/my-feature --status

   # See the next prompt Ralph will use - no magic!
   ./ralph.sh planning/my-feature --next-prompt
   ```

## Directory Structure

```
project-root/
├── planning/                          # Planning directories (one per feature)
│   └── my-feature/
│       ├── summary.md                 # Project overview
│       ├── memory.md                  # Learnings from iterations (auto-created)
│       ├── research/                  # Codebase research docs (optional)
│       ├── design/
│       │   └── detailed-design.md     # Technical design (optional)
│       └── implementation/
│           ├── plan.md                # Step checklist
│           ├── ralph.json             # Execution tracker with tasks
│           ├── progress.md            # Iteration history log
│           ├── step01/
│           │   ├── task-01-foo.code-task.md
│           │   └── task-02-bar.code-task.md
│           └── step02/
│               └── task-01-baz.code-task.md
│
└── archive/                           # Completed runs (optional)
    └── 2026-01-14-my-feature/
```

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Amp CLI](https://ampcode.com) (default)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
  - [OpenCode](https://github.com/AmruthPillai/OpenCode)
- Common shell utilities:
  - `jq` for JSON manipulation (`brew install jq` on macOS, `apt-get install jq` on Ubuntu)
  - `sponge` from moreutils (`brew install moreutils` on macOS, `apt-get install moreutils` on Ubuntu)
  - `git` of course
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

### Step 2: Install the skill

Copy the [Agent Skill](https://agentskills.io/) to your Amp or Claude config for use across all projects:

**For Amp:**
```bash
# From local clone
cp -r skills/ralph-sop ~/.config/amp/skills/

# Or via curl (no clone needed)
mkdir -p ~/.config/amp/skills/ralph-sop
curl -o ~/.config/amp/skills/ralph-sop/SKILL.md https://raw.githubusercontent.com/colinmollenhour/ralph/main/skills/ralph-sop/SKILL.md
```

**For Claude Code and OpenCode:**
```bash
# From local clone
cp -r skills/ralph-sop ~/.claude/skills/

# Or via curl (no clone needed)
mkdir -p ~/.claude/skills/ralph-sop
curl -o ~/.claude/skills/ralph-sop/SKILL.md https://raw.githubusercontent.com/colinmollenhour/ralph/main/skills/ralph-sop/SKILL.md
```

## Workflow

### Step 1. Create a planning directory

Create a planning directory with task specifications following the Agent SOP convention. Each task is a self-contained `.code-task.md` file with description, technical requirements, acceptance criteria (Given/When/Then), and references to design/research docs.

You can create these manually or use Agent SOP tooling. The key file is the `.code-task.md` spec -- each one should be small enough for an AI agent to complete in a single context window.

### Step 2. Generate the execution tracker

Use the `ralph-sop` skill to scan the task files and generate `ralph.json`:

```
Use the ralph-sop skill to prepare planning/my-feature
```

This creates `planning/my-feature/implementation/` with:
- `ralph.json` - Task list with `passes` status for each task
- `progress.md` - Iteration log initialized with header

### Step 3. Run Ralph

You are now ready to run Ralph. If you have just one project simply run `ralph.sh` and watch it go!

```bash
# Run specific project
ralph.sh planning/my-feature

# With options (can be combined)
ralph.sh planning/my-feature -n 10              # Max 10 iterations (default 50)
ralph.sh planning/my-feature --tool claude      # Use Claude Code
ralph.sh planning/my-feature --tool opencode    # Use OpenCode
ralph.sh planning/my-feature --next-prompt      # Inspect the next prompt without executing the agent
ralph.sh planning/my-feature --learn            # Normal execution + learn on final iteration
ralph.sh planning/my-feature --learn-now        # Just run the learn prompt to absorb memory.md into your main AGENTS.md
ralph.sh planning/my-feature --worktree         # Create a git worktree for isolated execution

# Stop a running Ralph gracefully (let it finish the current task before stopping)
ralph.sh planning/my-feature --stop
```

Run `ralph.sh --help` for all options.

Ralph will:
1. Create a feature branch (from `branchName` in `ralph.json` - and a worktree if `--worktree` is used)
2. Pick the highest priority task where `passes: false`
3. Read the `.code-task.md` spec and referenced design docs
4. Implement that single task
5. Run quality checks (lint, typecheck, tests)
6. Update `ralph.json` to mark task as `passes: true`
7. Append learnings to `memory.md`
8. Commit all changed files including the bookkeeping files
9. Repeat from step 2 until all tasks pass or max iterations reached (the loop)
10. Remove all planning files in the last commit (easy to recover)

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances |
| `planning/[feature]/` | Planning directories (one per feature) |
| `planning/[feature]/summary.md` | Project overview |
| `planning/[feature]/implementation/ralph.json` | Tasks with `passes` status (the task list) |
| `planning/[feature]/implementation/progress.md` | Iteration history |
| `planning/[feature]/memory.md` | Learnings for future iterations (created on first task) |
| `planning/[feature]/implementation/step*/task-*.code-task.md` | Individual task specifications |
| `skills/ralph-sop/` | Skill for generating ralph.json from task specs |
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
- `memory.md` (learnings from each iteration)
- `progress.md` (history log)
- `ralph.json` (which tasks are done)

### Token Efficiency

Ralph references task spec files by path rather than injecting their content. The agent reads the `.code-task.md` file which is self-contained with description, requirements, acceptance criteria, and references to design/research docs. Bookkeeping commands are pre-computed so the agent doesn't need to figure them out.

### Small Tasks

Each task should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized tasks:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### Learnings Storage

Each Ralph project has its own `memory.md` file (created automatically). Agents append learnings here during execution.

To absorb learnings into the project root `./AGENTS.md`:
```bash
./ralph.sh planning/my-feature --learn      # Absorb after all tasks complete
./ralph.sh planning/my-feature --learn-now  # or do it later after review
```

Examples of what is added to `memory.md`:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Feedback Loops

Ralph only works if there are solid feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Stop Condition

When all tasks have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Inspection/Debugging

Use `--next-prompt` to see exactly what context Ralph loads:
```bash
./ralph.sh planning/my-feature --next-prompt
```

This shows the full prompt with task spec references and progress context without invoking the agent.

Check current state:

```bash
# See which tasks are done
ralph.sh planning/my-feature --status

# See learnings from previous iterations
cat planning/my-feature/implementation/progress.md

# Check git history
git log --oneline -10
```

## Customizing the Prompt

The prompt should work well for general purposes but you can provide your own if your project needs different instructions like special
git commit message formats or automatically creating pull requests, running code review tools, etc.

Ralph looks for prompts in this order:
1. `--custom-prompt <file>` - Explicit flag takes highest priority
2. `<planning-dir>/.agents/ralph.md` - Project-local template (if exists)
3. Embedded default prompt

To customize for your project:
1. Run `ralph.sh --eject-prompt` which will create `.agents/ralph.md` in your project directory.
2. Modify it for your needs, probably add it to your repo.
3. Ralph will automatically use it over the embedded one for this project.

### Post-Completion Cleanup

When all tasks are complete, Ralph automatically removes planning files in a final commit, but of course they can be recovered.

```bash
# Revert the last commit
git reset --hard HEAD^

# Recover the files without changing history
git checkout HEAD~1 -- planning/my-feature/
```

**To disable cleanup:** Create a custom prompt template without the cleanup instructions in the Stop Condition section.

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved alongside the planning directory.

## Testing with test-project

A minimal test project is included to try Ralph without affecting your own codebase.

```bash
cd test-project

# Reset to initial state (creates git repo if needed - can do this multiple times)
./reset.sh

# Preview what Ralph will do
../ralph.sh planning/add-math-functions --next-prompt

# Run Ralph (requires amp, claude, or opencode to be installed)
../ralph.sh planning/add-math-functions --tool amp
# or
../ralph.sh planning/add-math-functions --tool claude
# or
../ralph.sh planning/add-math-functions --tool opencode
```

The test project has 5 tasks across 2 steps that add math functions to `src/math.ts`. Each task is small enough to complete in a single iteration, making it ideal for testing Ralph's behavior.

## References

- [Ryan Carson's original script](https://github.com/snarktank/ralph) which he wished to preserve as a simple script.
- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Amp documentation](https://ampcode.com/manual)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
