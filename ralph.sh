#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [OPTIONS] [ralph/feature | ralph/feature/ralph.json]
#
# Exit codes:
#   0 - All stories completed successfully
#   1 - Error occurred (invalid arguments, missing dependencies, max iterations reached)
#   2 - Gracefully stopped by user (--stop flag)

set -e

# Help function
show_help() {
  cat << 'EOF'
Ralph - Autonomous AI agent loop for completing PRD user stories

USAGE:
  ralph.sh [OPTIONS] [path] [-- tool_args...]

PATHS:
  ralph/auth                     Directory containing ralph.json
  ralph/auth/ralph.json          Explicit path to ralph.json
  (none)                         Interactive chooser from ralph/*/ralph.json

OPTIONS:
  -n, --number <N>       Maximum iterations to run (default: 50)
  --tool <name>          AI tool to use: amp, claude, or opencode (default: amp)
  --tool-path <path>     Explicit path to tool executable (overrides auto-detection)
  --custom-prompt <file> Use a custom prompt file instead of the embedded default
  --eject-prompt         Create .agents/ralph.md with the default prompt for customization
  --next-prompt          Debug mode: show what would be sent to LLM without running it
  --stop                 Signal Ralph to stop before the next iteration
  --help, -h             Show this help message
  --                     Everything after -- is passed to the tool as additional arguments

FLOW:
  ┌─────────────────┐    ralph skill     ┌─────────────────────┐    ralph.sh     ┌─────────────┐
  │ plans/foo.md    │ ────────────────►  │  ralph/foo/         │ ──────────────► │ Agent Loop  │
  │ (source PRD)    │     converts       │  ralph.json         │    executes     │             │
  └─────────────────┘                    │  README.md          │                 └─────────────┘
                                         │  progress.txt       │
                                         └─────────────────────┘

FAILURE HANDLING:
  Ralph detects rapid failures (iterations < 4 seconds) and exits after 5 consecutive
  quick failures. This prevents rate limit issues and catches configuration errors early.

EXAMPLES:
  ralph.sh                              # Interactive chooser
  ralph.sh ralph/auth                   # Run specific project (by directory)
  ralph.sh ralph/auth/ralph.json        # Run specific project (explicit path)
  ralph.sh -n 5 ralph/auth              # Run with 5 max iterations
  ralph.sh ralph/auth -n 5              # Flags can come after path
  ralph.sh --next-prompt ralph/auth     # Debug: see prompt without running LLM
  ralph.sh --tool claude ralph/auth     # Run with Claude Code
  ralph.sh --stop ralph/auth            # Stop a running Ralph project

GETTING STARTED:
  1. Create a PRD using the 'prd' skill:
     > Use the prd skill to create a PRD for user authentication
     This creates plans/auth.md

  2. Convert to Ralph format using the 'ralph' skill:
     > Use the ralph skill to convert plans/auth.md
     This creates ralph/auth/ with ralph.json, README.md, progress.txt

  3. Run Ralph:
     $ ./ralph.sh ralph/auth

CUSTOMIZING THE PROMPT:
  Ralph uses prompts in this priority order:
  1. --custom-prompt <file> (explicit flag)
  2. [ralph-dir]/.agents/ralph.md (project-local template, if exists)
  3. Embedded default prompt

  To customize for your project:
  1. Run: ./ralph.sh --eject-prompt ralph/auth
  2. Edit ralph/auth/.agents/ralph.md
  3. Ralph will automatically use it

EXIT CODES:
  0 - All stories completed successfully
  1 - Error occurred (invalid arguments, missing dependencies, max iterations reached)
  2 - Gracefully stopped by user (--stop flag)

EOF
  exit 0
}

# Parse arguments
TOOL="amp"  # Default to amp for backwards compatibility
MAX_ITERATIONS=50
TOOL_ARGS=()  # Additional args to pass to the tool
CUSTOM_PROMPT=""  # Optional custom prompt file
TOOL_PATH=""  # Optional explicit path to tool executable
EJECT_PROMPT_FLAG=false  # Flag for --eject-prompt
RALPH_JSON=""  # Path to ralph.json
NEXT_PROMPT_FLAG=false  # Debug mode

while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      show_help
      ;;
    --next-prompt)
      NEXT_PROMPT_FLAG=true
      shift
      ;;
    -n|--number)
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --eject-prompt)
      # Set flag to eject prompt after functions are defined
      EJECT_PROMPT_FLAG=true
      shift
      ;;
    --stop)
      # Handle stop after we know the ralph directory
      # For now just set a flag
      STOP_FLAG=true
      shift
      ;;
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --tool-path)
      TOOL_PATH="$2"
      shift 2
      ;;
    --tool-path=*)
      TOOL_PATH="${1#*=}"
      shift
      ;;
    --custom-prompt)
      CUSTOM_PROMPT="$2"
      shift 2
      ;;
    --custom-prompt=*)
      CUSTOM_PROMPT="${1#*=}"
      shift
      ;;
    --)
      # Everything after -- is passed to the tool
      shift
      TOOL_ARGS=("$@")
      break
      ;;
    *)
      # Assume it's a path to ralph.json or directory
      if [[ -z "$RALPH_JSON" ]]; then
        if [[ -d "$1" ]]; then
          # Directory given - look for ralph.json inside
          if [[ -f "$1/ralph.json" ]]; then
            RALPH_JSON="$1/ralph.json"
          else
            echo "Error: No ralph.json found in $1"
            exit 1
          fi
        elif [[ -f "$1" ]]; then
          # File given - verify it's ralph.json
          if [[ "$(basename "$1")" != "ralph.json" ]]; then
            echo "Error: File must be named ralph.json, got: $1"
            exit 1
          fi
          RALPH_JSON="$1"
        else
          echo "Error: Path not found: $1"
          exit 1
        fi
        shift
      else
        echo "Error: Multiple paths specified"
        exit 1
      fi
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" && "$TOOL" != "opencode" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp', 'claude', or 'opencode'."
  exit 1
fi

# Check if the selected tool exists
TOOL_CMD="$TOOL"  # Default to the tool name

if [[ -n "$TOOL_PATH" ]]; then
  # Use explicit tool path if provided
  if [[ ! -f "$TOOL_PATH" ]]; then
    echo "Error: Tool path not found: $TOOL_PATH"
    exit 1
  fi
  if [[ ! -x "$TOOL_PATH" ]]; then
    echo "Error: Tool path is not executable: $TOOL_PATH"
    exit 1
  fi
  TOOL_CMD="$TOOL_PATH"
  echo "Using explicit tool path: $TOOL_PATH"
elif ! type "$TOOL" &> /dev/null; then
  # Tool not in PATH, check for known fallback locations
  if [[ "$TOOL" == "claude" ]] && [[ -f "$HOME/.claude/local/claude" ]]; then
    echo "Using local Claude installation: ~/.claude/local/claude"
    TOOL_CMD="$HOME/.claude/local/claude"
  else
    echo "Error: Tool '$TOOL' is not available."
    echo "Please install or configure '$TOOL' before running Ralph."
    echo "Alternatively, use --tool-path to specify the exact path to the tool."
    exit 1
  fi
fi

# Validate custom prompt file if provided
if [[ -n "$CUSTOM_PROMPT" ]] && [[ ! -f "$CUSTOM_PROMPT" ]]; then
  echo "Error: Custom prompt file not found: $CUSTOM_PROMPT"
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed."
  echo "Please install jq: https://jqlang.github.io/jq/download/"
  exit 1
fi

# Check if sponge is available
if ! command -v sponge &> /dev/null; then
  echo "Error: sponge (from moreutils) is required but not installed."
  echo "Install with: brew install moreutils (macOS) or apt-get install moreutils (Ubuntu)"
  exit 1
fi

# If no RALPH_JSON specified, show interactive chooser
if [[ -z "$RALPH_JSON" ]] && [[ "$EJECT_PROMPT_FLAG" != true ]]; then
  # Find all ralph.json files
  mapfile -t RALPH_FILES < <(find ralph -name "ralph.json" -type f 2>/dev/null | grep -v "archive/" | sort)
  
  if [[ ${#RALPH_FILES[@]} -eq 0 ]]; then
    echo "Error: No Ralph projects found in ralph/"
    echo "Use the 'ralph' skill to convert a PRD to ralph.json first."
    exit 1
  fi
  
  # Build menu with completion stats (output to stderr so it doesn't pollute stdout for piping)
  INCOMPLETE_FILES=()
  echo "" >&2
  echo "Available Ralph projects:" >&2
  echo "" >&2
  
  for i in "${!RALPH_FILES[@]}"; do
    file="${RALPH_FILES[$i]}"
    desc=$(jq -r '.description // "Unknown"' "$file" 2>/dev/null)
    total=$(jq '.userStories | length' "$file" 2>/dev/null || echo "0")
    complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$file" 2>/dev/null || echo "0")
    
    num=$((i + 1))
    
    if [[ "$complete" -eq "$total" ]]; then
      echo "  $num. $desc ($complete/$total complete) [DONE]" >&2
    else
      echo "  $num. $desc ($complete/$total complete)" >&2
      INCOMPLETE_FILES+=("$file")
    fi
  done
  
  echo "" >&2
  
  # Auto-select if exactly one incomplete
  if [[ ${#INCOMPLETE_FILES[@]} -eq 1 ]]; then
    RALPH_JSON="${INCOMPLETE_FILES[0]}"
    echo "Auto-selected: $RALPH_JSON" >&2
    echo "" >&2
  elif [[ ${#INCOMPLETE_FILES[@]} -eq 0 ]]; then
    echo "All projects complete!" >&2
    exit 0
  else
    # Prompt for selection
    read -p "Select a project [1-${#RALPH_FILES[@]}]: " selection
    
    if [[ -z "$selection" ]]; then
      echo "Error: No selection made" >&2
      exit 1
    elif [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo "Error: Selection must be a number" >&2
      exit 1
    elif [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "${#RALPH_FILES[@]}" ]]; then
      echo "Error: Selection out of range (1-${#RALPH_FILES[@]})" >&2
      exit 1
    fi
    
    RALPH_JSON="${RALPH_FILES[$((selection - 1))]}"
  fi
fi

# Extract directory from ralph.json path
if [[ -n "$RALPH_JSON" ]]; then
  RALPH_DIR=$(dirname "$RALPH_JSON")  # e.g., ralph/auth
  PROGRESS_FILE="$RALPH_DIR/progress.txt"
  ARCHIVE_DIR="ralph/archive"
  LAST_BRANCH_FILE="$RALPH_DIR/.last-branch"
  STOP_FILE="$RALPH_DIR/.ralph-stop"
fi

# Handle --stop flag now that we know the directory
if [[ "$STOP_FLAG" == true ]]; then
  if [[ -z "$RALPH_JSON" ]]; then
    echo "Error: --stop requires a ralph project path"
    exit 1
  fi
  touch "$STOP_FILE"
  echo "Stop signal sent. Ralph will stop before the next iteration."
  exit 0
fi

# Helper function to initialize progress file header
init_progress_header() {
  local ralph_json="$1"
  local tool="$2"
  local tool_args="$3"

  echo "# Ralph Progress Log"
  echo "Started: $(date '+%Y-%m-%d %H:%M')"
  echo "Tool: $tool"

  # Add tool args if present
  if [[ -n "$tool_args" ]]; then
    echo "Tool args: $tool_args"
  fi

  # Extract and add source from ralph.json if present
  if [ -f "$ralph_json" ]; then
    local source=$(jq -r '.source // empty' "$ralph_json" 2>/dev/null || echo "")
    if [[ -n "$source" ]]; then
      echo "Source PRD: $source"
    fi
  fi

  echo "---"
  echo ""
  echo "## Codebase Patterns"
  echo "(Agents will populate this section with reusable learnings)"
  echo ""
  echo "## Iteration History"
}

# Generate the prompt - conditionally include AMP thread URL section
generate_prompt() {
  local tool="$1"
  
  # Base prompt content
  # Note: Uses $RALPH_JSON and $PROGRESS_FILE placeholders - these are substituted
  # with actual paths by sed before sending to the agent
  cat << 'PROMPT_START'
You are to complete one task from the Ralph project which is represented by the files in: $RALPH_DIR

## Token Efficiency Rules (Critical)

To minimize token usage on each iteration:

1. **NEVER read the ralph.json directly** - Use jq queries exclusively:
   ```bash
   # Get current story
   jq '[.userStories[] | select(.passes == false)] | min_by(.priority)' "$RALPH_JSON"
   
   # Get branch name
   jq -r '.branchName' "$RALPH_JSON"
   
   # Check if all complete
   jq 'all(.userStories[]; .passes == true)' "$RALPH_JSON"
   ```

2. **Load context files surgically** (all paths relative to project root):
   ```bash
   # Primary plan (always present)
   cat $(jq -r '.source' "$RALPH_JSON")
   
   # Story-specific plan (optional - only if story has source field)
   STORY_SOURCE=$(jq -r '[.userStories[] | select(.passes == false)] | min_by(.priority) | .source // empty' "$RALPH_JSON")
   [[ -n "$STORY_SOURCE" ]] && cat "$STORY_SOURCE"
   ```

3. **Load progress context efficiently**:
   ```bash
   # Patterns + header (always small)
   sed -n '1,/^## Iteration History/p' "$PROGRESS_FILE"
   
   # Recent history (last 50 lines for context)
   tail -n 50 "$PROGRESS_FILE"
   ```

## Your Task

1. Get the next story to work on:
   ```bash
   jq '[.userStories[] | select(.passes == false)] | min_by(.priority)' "$RALPH_JSON"
   ```

2. Load context files (see Token Efficiency Rules above for exact commands)

3. Get branch name and check out/create:
   ```bash
   BRANCH=$(jq -r '.branchName' "$RALPH_JSON")
   git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
   ```

4. Work on the user story (all requirements in story's description and acceptanceCriteria)

5. Run quality checks (typecheck, lint, test - use whatever your project requires)

6. Update AGENTS.md files if you discover reusable patterns (see below)

7. If checks pass, commit ALL changes:
   ```bash
   STORY_ID=$(jq -r '[.userStories[] | select(.passes == false)] | min_by(.priority) | .id' "$RALPH_JSON")
   STORY_TITLE=$(jq -r '[.userStories[] | select(.passes == false)] | min_by(.priority) | .title' "$RALPH_JSON")
   git commit -m "feat: $STORY_ID - $STORY_TITLE"
   ```

8. Update the story status:
   ```bash
   jq '(.userStories[] | select(.id == "'"$STORY_ID"'") | .passes) = true' "$RALPH_JSON" > "$RALPH_JSON.tmp" && mv "$RALPH_JSON.tmp" "$RALPH_JSON"
   ```

9. Append your progress to $PROGRESS_FILE

## Progress Report Format

APPEND to $PROGRESS_FILE (never replace, always append):

```
### [YYYY-MM-DD HH:MM] - [Story ID]
PROMPT_START

  if [[ "$tool" == "amp" ]]; then
    echo 'Thread: https://ampcode.com/threads/$AMP_CURRENT_THREAD_ID'
  fi

  cat << 'PROMPT_END'
Implemented: [1-2 sentence summary]
Files changed:
- path/to/file.ts (created/modified/deleted)
- path/to/other.ts

 * Learning 1 (important patterns, gotchas, or context for future iterations)
 * Learning 2 (prefix with space + asterisk + space for parseability)
 * Learning 3 (use - for regular history items, * for learnings)
---
```

**Important about learnings:**
- Use ` * ` prefix (space-asterisk-space) for learnings
- Use `-` for regular history/file lists
- This allows extracting just learnings with: `grep '^ \* ' "$PROGRESS_FILE"`
- Keep learnings focused and actionable for future iterations

PROMPT_END

  if [[ "$tool" == "amp" ]]; then
    cat << 'PROMPT_END'

Include the thread URL so future iterations can use the `read_thread` tool to reference previous work if needed.
PROMPT_END
  fi

  cat << 'PROMPT_END'

## Consolidate Patterns

If you discover a **reusable pattern**, add it to the `## Codebase Patterns` section at the TOP of $PROGRESS_FILE (create if doesn't exist):

```
## Codebase Patterns
 * Use sql<number> template for aggregations
 * Always use IF NOT EXISTS for migrations
 * Export types from actions.ts for UI components
```

Only add patterns that are **general and reusable**, not story-specific details.

## Update AGENTS.md Files

Before committing, check if any edited files have learnings worth preserving in nearby AGENTS.md files:

1. **Identify directories with edited files**
2. **Check for existing AGENTS.md** in those directories or parents
3. **Add valuable learnings** like:
   - API patterns or conventions specific to that module
   - Gotchas or non-obvious requirements
   - Dependencies between files
   - Testing approaches for that area

Only update AGENTS.md if you have **genuinely reusable knowledge** for that directory.

## Quality Requirements

- ALL commits must pass your project's quality checks (typecheck, lint, test)
- Do NOT commit broken code
- Keep changes focused and minimal
- Follow existing code patterns

## Browser Testing (Required for Frontend Stories)

For any story that changes UI, you MUST verify it works in the browser:

1. Load the `dev-browser` skill
2. Navigate to the relevant page
3. Verify the UI changes work as expected
4. Take a screenshot if helpful for the progress log

A frontend story is NOT complete until browser verification passes.

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`:

```bash
jq 'all(.userStories[]; .passes == true)' "$RALPH_JSON"
```

If ALL stories are complete and passing:

1. **Perform cleanup commit** - Remove Ralph working files from git but keep locally:
   ```bash
   # Remove from git but keep on disk
   git rm --cached -r "$RALPH_DIR"
   git commit -m "chore: cleanup $RALPH_DIR working files"
   ```

2. Then reply with: <promise>COMPLETE</promise>

The working files remain on disk in `ralph/auth/` for reference, but are removed from the branch.
To restore: `git checkout HEAD~1 -- ralph/auth/`

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## Important

- Work on ONE story per iteration
- Commit frequently
- Keep CI green
- Read the Codebase Patterns section in $PROGRESS_FILE before starting
PROMPT_END
}

# Handle --eject-prompt flag (now that generate_prompt is defined)
if [ "$EJECT_PROMPT_FLAG" = true ]; then
  if [[ -z "$RALPH_JSON" ]]; then
    echo "Error: --eject-prompt requires a ralph project path"
    echo "Usage: ./ralph.sh --eject-prompt ralph/auth"
    exit 1
  fi
  
  EJECT_DIR="$RALPH_DIR/.agents"
  EJECT_FILE="$EJECT_DIR/ralph.md"
  
  if [ -f "$EJECT_FILE" ]; then
    echo "Error: $EJECT_FILE already exists."
    echo "Delete it first if you want to regenerate it."
    exit 1
  fi
  
  mkdir -p "$EJECT_DIR"
  
  # Add header comment explaining available variables, then the prompt
  {
    cat << 'EJECT_HEADER'
<!-- Ralph Prompt Template

Available variables (substituted at runtime with actual paths):
  RALPH_DIR      - Ralph project directory (e.g., ralph/auth)
  RALPH_JSON     - Path to ralph.json (e.g., ralph/auth/ralph.json)  
  PROGRESS_FILE  - Path to progress.txt (e.g., ralph/auth/progress.txt)

In your prompt, use these as: $RALPH_DIR, $RALPH_JSON, $PROGRESS_FILE
They are replaced with actual values when Ralph runs.

-->

EJECT_HEADER
    generate_prompt "$TOOL"
  } > "$EJECT_FILE"
  
  echo "Created $EJECT_FILE"
  echo ""
  echo "This file will now be used automatically when running ralph.sh for this project."
  echo "Edit it to customize the prompt for your project."
  echo ""
  echo "Available variables: \$RALPH_DIR, \$RALPH_JSON, \$PROGRESS_FILE"
  exit 0
fi

# Handle --next-prompt flag
# Headers go to stderr so prompt content can be piped to an agent
if [[ "$NEXT_PROMPT_FLAG" = true ]]; then
  if [[ -z "$RALPH_JSON" ]]; then
    echo "Error: --next-prompt requires a ralph project path" >&2
    exit 1
  fi
  
  echo "========== PROMPT (with paths substituted) ==========" >&2
  # Show the prompt with variables substituted to actual paths
  if [[ -n "$CUSTOM_PROMPT" ]]; then
    sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
        -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
        -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g" \
        "$CUSTOM_PROMPT"
  elif [[ -f "$RALPH_DIR/.agents/ralph.md" ]]; then
    sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
        -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
        -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g" \
        "$RALPH_DIR/.agents/ralph.md"
  else
    generate_prompt "$TOOL" | sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
                                  -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
                                  -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g"
  fi
  
  exit 0
fi

# Validate ralph.json exists
if [[ -z "$RALPH_JSON" ]] || [[ ! -f "$RALPH_JSON" ]]; then
  echo "Error: ralph.json not found."
  echo "Use the 'ralph' skill to convert a PRD to ralph.json first."
  exit 1
fi

# Archive previous run if branch changed
if [ -f "$RALPH_JSON" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$RALPH_JSON" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$RALPH_JSON" ] && cp "$RALPH_JSON" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    init_progress_header "$RALPH_JSON" "$TOOL" "${TOOL_ARGS[*]}" > "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$RALPH_JSON" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$RALPH_JSON" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  init_progress_header "$RALPH_JSON" "$TOOL" "${TOOL_ARGS[*]}" > "$PROGRESS_FILE"
fi

# Check for project-local prompt template and show message once
if [[ -z "$CUSTOM_PROMPT" ]] && [[ -f "$RALPH_DIR/.agents/ralph.md" ]]; then
  echo "Using project-local prompt: $RALPH_DIR/.agents/ralph.md"
fi

echo "Starting Ralph - Project: $RALPH_DIR - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

# Failure tracking for circuit breaker
CONSECUTIVE_FAILURES=0
MAX_FAILURES=5
MIN_ITERATION_TIME=4  # seconds - iterations faster than this are considered failures

for i in $(seq 1 $MAX_ITERATIONS); do
  # Check for stop signal
  if [ -f "$STOP_FILE" ]; then
    echo ""
    echo "Stop signal detected. Stopping gracefully..."
    rm -f "$STOP_FILE"
    exit 2
  fi

  # Check if all stories complete
  ALL_COMPLETE=$(jq 'all(.userStories[]; .passes == true)' "$RALPH_JSON" 2>/dev/null || echo "false")
  if [ "$ALL_COMPLETE" = "true" ]; then
    echo ""
    echo "Ralph already completed! All stories pass."
    exit 0
  fi

  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "  Project: $RALPH_DIR"
  echo "==============================================================="

  # Generate the prompt - priority: --custom-prompt > .agents/ralph.md > embedded default
  # Substitute $RALPH_DIR, $RALPH_JSON, $PROGRESS_FILE with actual paths
  if [[ -n "$CUSTOM_PROMPT" ]]; then
    PROMPT=$(sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
                 -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
                 -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g" \
                 "$CUSTOM_PROMPT")
  elif [[ -f "$RALPH_DIR/.agents/ralph.md" ]]; then
    PROMPT=$(sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
                 -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
                 -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g" \
                 "$RALPH_DIR/.agents/ralph.md")
  else
    PROMPT=$(generate_prompt "$TOOL" | sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
                                           -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
                                           -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g")
  fi

  # Record start time for failure detection
  ITERATION_START=$(date +%s)

  # Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(echo "$PROMPT" | "$TOOL_CMD" --dangerously-allow-all "${TOOL_ARGS[@]}" 2>&1 | tee /dev/stderr) || true
  elif [[ "$TOOL" == "claude" ]]; then
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    OUTPUT=$(echo "$PROMPT" | "$TOOL_CMD" --dangerously-skip-permissions --print "${TOOL_ARGS[@]}" 2>&1 | tee /dev/stderr) || true
  else
    # OpenCode: use run command for non-interactive mode
    if ((${#TOOL_ARGS[@]})); then
      OUTPUT=$("$TOOL_CMD" run "$PROMPT" "${TOOL_ARGS[@]}" 2>&1 | tee /dev/stderr) || true
    else
      OUTPUT=$("$TOOL_CMD" run "$PROMPT" 2>&1 | tee /dev/stderr) || true
    fi
  fi
  
  # Calculate iteration duration
  ITERATION_END=$(date +%s)
  ITERATION_DURATION=$((ITERATION_END - ITERATION_START))
  
  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    echo ""
    echo "Working files have been cleaned up in a separate commit."
    echo "To undo cleanup: git revert HEAD"
    echo "To recover files: git checkout HEAD~1 -- $RALPH_DIR/"
    exit 0
  fi
  
  # Detect rapid failures (tool exiting too quickly)
  if [ "$ITERATION_DURATION" -lt "$MIN_ITERATION_TIME" ]; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo ""
    echo "Warning: Iteration completed very quickly (${ITERATION_DURATION}s). This may indicate an error."
    echo "Consecutive quick failures: $CONSECUTIVE_FAILURES/$MAX_FAILURES"
    
    if [ "$CONSECUTIVE_FAILURES" -ge "$MAX_FAILURES" ]; then
      echo ""
      echo "Error: Too many consecutive quick failures ($MAX_FAILURES)."
      echo "This usually indicates a configuration problem (e.g., invalid model, missing permissions)."
      echo "Please check the error messages above and fix the issue before retrying."
      exit 1
    fi
    
    echo "Sleeping 3 seconds before retry..."
    sleep 3
  else
    # Reset failure counter on successful iteration
    CONSECUTIVE_FAILURES=0
    echo "Iteration $i complete. Continuing..."
    sleep 2
  fi
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
