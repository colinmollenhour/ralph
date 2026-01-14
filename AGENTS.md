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
  - `progress.txt` - Iteration log with learnings
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

Ralph is optimized to minimize token usage per iteration. Agents should follow these rules:

### Never Read Full Files

1. **PRD access** - Use `jq` exclusively, never read `ralph.json`:
   ```bash
   # Get current task
   jq '[.userStories[] | select(.passes == false)] | min_by(.priority)' ralph.json
   
   # Get branch name
   jq -r '.branchName' ralph.json
   
   # Check if all complete
   jq 'all(.userStories[]; .passes == true)' ralph.json
   
   # Update story status
   jq '(.userStories[] | select(.id == "US-001") | .passes) = true' ralph.json | sponge ralph.json
   ```

2. **Progress file** - Only read Codebase Patterns section:
   ```bash
   # Extract patterns + header
   sed -n '1,/^## Iteration History/p' progress.txt
   
   # Recent history (last 50 lines)
   tail -n 50 progress.txt
   ```

3. **Source PRD files** - Load surgically:
   ```bash
   # Primary plan
   cat $(jq -r '.source' ralph.json)
   
   # Story-specific plan (only if story has source field)
   STORY_SOURCE=$(jq -r '[.userStories[] | select(.passes == false)] | min_by(.priority) | .source // empty' ralph.json)
   [[ -n "$STORY_SOURCE" ]] && cat "$STORY_SOURCE"
   ```

### Progress File Format

Learnings use ` * ` prefix for parseability:

```
### [2026-01-14 10:30] - US-002
Implemented: Login form component with email/password validation
Files changed:
- src/components/LoginForm.vue (created)

 * Use UFormGroup for all form inputs (Nuxt UI pattern)
 * Form validation with zod schema in same file
 * Error messages displayed using UAlert component
---
```

Extract learnings: `grep '^ \* ' progress.txt`
Exclude learnings: `grep -v '^ \* ' progress.txt`

### Surgical Code Exploration

- Use focused `grep` with specific patterns, not broad searches
- Use `glob` with narrow patterns targeting specific files
- Only read files directly related to the current story
- Avoid exploratory codebase walks - rely on Codebase Patterns instead

### Expected Token Savings

Following these patterns, a typical Ralph iteration context loading should use:
- ~800-1000 tokens for the embedded prompt
- ~300-600 tokens for primary plan (README.md)
- ~200-500 tokens for story-specific domain (if split)
- ~100-300 tokens for patterns section from progress.txt
- **Total: ~1400-2400 tokens** for context loading

The old approach (reading full prd.json, progress.txt, and source PRD) typically used ~8000-15000 tokens. This redesign achieves approximately **70-80% reduction** in context overhead, leaving more tokens available for actual code work.
