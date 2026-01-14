# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs AI coding tools (Amp, Claude Code, or OpenCode) repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context.

## Commands

```bash
# Run Ralph (interactive chooser if no path given)
./ralph.sh

# Run specific Ralph project
./ralph.sh ralph/auth
./ralph.sh ralph/auth/ralph.json

# Run with iteration limit
./ralph.sh ralph/auth -n 10
./ralph.sh -n 10 ralph/auth  # Either order works

# Debug: See next prompt without invoking LLM
./ralph.sh ralph/auth --next-prompt

# Run with different tools
./ralph.sh ralph/auth --tool claude
./ralph.sh ralph/auth --tool opencode

# Stop a running Ralph project
./ralph.sh --stop ralph/auth

# Run with learning absorption
./ralph.sh ralph/auth --learn           # Normal execution + learn on final iteration
./ralph.sh ralph/auth --learn-now       # Just run learn prompt, no tasks

# Run the flowchart dev server
cd flowchart && npm run dev

# Build the flowchart
cd flowchart && npm run build
```

## Key Files

- `ralph.sh` - Main loop script with embedded agent prompt
- `plans/` - Source PRDs (user-created, read-only by Ralph)
- `ralph/[feature]/` - Execution directories (auto-generated):
  - `README.md` - Primary plan
  - `ralph.json` - Execution config with user stories
  - `progress.txt` - Simple iteration history
  - `AGENTS.md` - Learnings (created on first task execution)
  - `[domain].md` - Domain-specific plans (if split)
- `ralph/archive/` - Archived completed runs

## Flowchart

The `flowchart/` directory contains an interactive visualization built with React Flow. It's designed for presentations - click through to reveal each step with animations.

To run locally:
```bash
cd flowchart
npm install
npm run dev
```

## Patterns

- Each iteration spawns a fresh AI instance (Amp, Claude Code, or OpenCode) with clean context
- Memory persists via git history, `progress.txt`, and `ralph.json`
- Stories should be small enough to complete in one context window
- Always update AGENTS.md with discovered patterns for future iterations
- **Early exit optimization**: The loop checks if all stories are complete at the start of each iteration
- **Failure detection**: Iterations completing in less than 4 seconds are flagged as potential failures. After 5 consecutive quick failures, Ralph exits with an error to prevent rate limiting and catch configuration issues (e.g., invalid model names)
- **Default iterations**: Set to 50 since early exit optimization prevents wasted iterations when work is complete

## Token Efficiency Patterns

Ralph pre-computes all context and injects it directly into the prompt to minimize agent tool calls.

### Progress File Format

Simple iteration history (no special formatting):

```
### [2026-01-14 10:30] - US-002
Implemented: Login form component with email/password validation
Files changed:
- src/components/LoginForm.vue (created)
---
```

### Learnings Storage

Learnings are stored in `ralph/[feature]/AGENTS.md` (created automatically on first task execution).
Use `--learn` or `--learn-now` flags to absorb learnings into the project root `./AGENTS.md`.

### Expected Token Savings

With pre-computed variables, a typical Ralph iteration prompt uses:
- ~1500-2500 tokens for the full prompt with story details
- ~200-500 tokens for story-specific domain (if split)
- ~100-500 tokens for learnings from AGENTS.md
- **Total: ~1800-3500 tokens** for complete context

This represents approximately **70-80% reduction** in context overhead compared to the agent reading files directly.
