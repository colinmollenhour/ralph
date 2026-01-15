#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [OPTIONS] [ralph/feature | ralph/feature/ralph.json]
#
# Exit codes:
#   0 - All stories completed successfully
#   1 - Error occurred (invalid arguments, missing dependencies, max iterations reached)
#   2 - Gracefully stopped by user (--stop flag)

set -e

# =============================================================================
# Color and Emoji Support
# =============================================================================
# Respects NO_COLOR environment variable (https://no-color.org/)
# Also auto-disables when stdout is not a terminal (e.g., piping to file)

setup_colors() {
  if [[ "${NO_COLOR:-}" == "true" ]] || [[ "${NO_COLOR:-}" == "1" ]] || [[ ! -t 1 ]]; then
    # No colors
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
    # No emojis
    E_ROCKET='' E_CHECK='' E_PARTY='' E_FINISH='' E_SPARKLE=''
    E_WARN='' E_ERROR='' E_STOP='' E_CLOCK='' E_BOOK='' E_FILE=''
    E_FOLDER='' E_MEMO='' E_CHART='' E_LOOP='' E_BOX_CHECK='' E_BOX_EMPTY=''
  else
    # ANSI color codes
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'  # No Color / Reset
    # Emojis
    E_ROCKET='🚀'
    E_CHECK='✅'
    E_PARTY='🎉'
    E_FINISH='🏁'
    E_SPARKLE='✨'
    E_WARN='⚠️ '
    E_ERROR='❌'
    E_STOP='🛑'
    E_CLOCK='⏱️ '
    E_BOOK='📚'
    E_FILE='📄'
    E_FOLDER='📁'
    E_MEMO='📝'
    E_CHART='📊'
    E_LOOP='🔄'
    E_BOX_CHECK='✅'
    E_BOX_EMPTY='⬜'
  fi
}

# Initialize colors (may be called again after parsing --no-color flag)
setup_colors

# Global variables for cleanup
TOOL_PID=""
OPENCODE_SERVER_PID=""
OPENCODE_PORT=""

# Cleanup function to reset terminal on exit
cleanup_terminal() {
  # Reset terminal state if stderr is a TTY
  if [[ -t 2 ]]; then
    # Clear line 1 (status bar), reset scrolling region, and move to bottom
    printf "\033[1;1H\033[K\033[r\033[999B\n" >&2
  fi
}

# Cleanup function for interrupts (INT signal)
cleanup_interrupt() {
  echo ""
  echo -e "${YELLOW}${E_STOP} Interrupt received, cleaning up...${NC}"
  
  # Kill current tool process if running
  if [[ -n "$TOOL_PID" ]] && kill -0 "$TOOL_PID" 2>/dev/null; then
    kill "$TOOL_PID" 2>/dev/null || true
    wait "$TOOL_PID" 2>/dev/null || true
  fi
  
  # Kill opencode server if running
  if [[ -n "$OPENCODE_SERVER_PID" ]] && kill -0 "$OPENCODE_SERVER_PID" 2>/dev/null; then
    echo -e "${DIM}Stopping OpenCode server (PID $OPENCODE_SERVER_PID)...${NC}"
    kill "$OPENCODE_SERVER_PID" 2>/dev/null || true
    wait "$OPENCODE_SERVER_PID" 2>/dev/null || true
  fi

  # Show worktree message if in worktree mode
  if [[ "$WORKTREE_FLAG" == true ]] && [[ -n "$WORKTREE_DIR_RELATIVE" ]]; then
    echo -e "${CYAN}Worktree left intact: ${WORKTREE_DIR_RELATIVE}${NC}"
  fi

  cleanup_terminal
  exit 130  # Standard exit code for SIGINT
}

# Set up trap to cleanup terminal on exit
trap cleanup_terminal EXIT
trap cleanup_interrupt INT

# =============================================================================
# Help function
# =============================================================================
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
  --eject-prompt         Create .agents/ralph.md prompt template for customization
  --next-prompt          Debug mode: show what would be sent to LLM without running it
  --status               Show project status (stories, progress, metadata)
  --stop                 Signal Ralph to stop before the next iteration
  --learn                Add learn section to prompt; runs learn-only if all stories complete
  --learn-now            Run only the learn prompt (absorb learnings into ./AGENTS.md)
  --worktree             Run in a git worktree (creates .worktrees/<feature>/)
  --no-color             Disable colors and emojis (also respects NO_COLOR env var)
  --help, -h             Show this help message
  --                     Everything after -- is passed to the tool as additional arguments

FLOW:
  ┌─────────────────┐  ralph-prep skill  ┌─────────────────────┐    ralph.sh     ┌─────────────┐
  │ plans/foo.md    │ ────────────────►  │  ralph/foo/         │ ──────────────► │ Agent Loop  │
  │ (source PRD)    │     converts       │   - ralph.json      │    executes     │             │
  └─────────────────┘                    │   - README.md       │                 └─────────────┘
                                         │   - progress.txt    │
                                         └─────────────────────┘

FAILURE HANDLING:
  Ralph detects rapid failures (iterations < 4 seconds) and exits after 5 consecutive
  quick failures. This prevents rate limit issues and catches configuration errors early.

EXAMPLES:
  ralph.sh                              # Interactive chooser
  ralph.sh ralph/auth                   # Run specific project (by directory)
  ralph.sh ralph/auth/ralph.json        # Run specific project (explicit path)
  ralph.sh ralph/auth -n 5              # Run with max of 5 iterations (default 50)
  ralph.sh -n 5 ralph/auth              # Flags can come before or after path
  ralph.sh ralph/auth --next-prompt     # Debug: see prompt without running LLM
  ralph.sh ralph/auth --status          # Show project status
  ralph.sh ralph/auth --tool claude     # Run with Claude Code
  ralph.sh ralph/auth --stop            # Stop a running Ralph project
  ralph.sh ralph/auth --learn           # Normal execution + learn on final iteration
  ralph.sh ralph/auth --learn-now       # Just run learn prompt, no tasks
  ralph.sh ralph/auth --worktree        # Run in isolated git worktree (run multiple Ralphs on different plans in parallel)
  ralph.sh --eject-prompt               # Create reusable prompt template for customization
  ralph.sh --no-color ralph/auth        # Run without colors/emojis

GETTING STARTED:
  1. Create a PRD (optional - use 'ralph-prd' skill or write manually):
     > Use the ralph-prd skill to create a PRD for user authentication as discussed
     This creates plans/PRD-auth.md

  2. Convert to Ralph format using the 'ralph-prep' skill (REQUIRED):
     > Use the ralph-prep skill to prepare plans/PRD-auth.md for Ralph
     This creates ralph/auth/ with ralph.json, README.md, progress.txt

  3. Run Ralph:
     $ ./ralph.sh ralph/auth

CUSTOMIZING THE PROMPT:
  Ralph kicks off each agent with a prompt. The prompt source is determined in this priority order:
  1. --custom-prompt <file> (explicit flag)
  2. [ralph-dir]/.agents/ralph.md (project-local template, if exists)
  3. Embedded default prompt

  To customize for your project:
  1. Run: ./ralph.sh --eject-prompt to create .agents/ralph.md in your project
  3. Edit .agents/ralph.md
  4. Ralph will automatically use it - or copy it elsewhere and use --custom-prompt path/to/my/prompt.md

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
LEARN_FLAG=false  # Flag for --learn
LEARN_NOW_FLAG=false  # Flag for --learn-now
STATUS_FLAG=false  # Flag for --status
WORKTREE_FLAG=false  # Flag for --worktree
WORKTREE_BASE=".worktrees"  # Base directory for worktrees

while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      show_help
      ;;
    --next-prompt)
      NEXT_PROMPT_FLAG=true
      shift
      ;;
    --learn)
      LEARN_FLAG=true
      shift
      ;;
    --learn-now)
      LEARN_NOW_FLAG=true
      shift
      ;;
    --status)
      STATUS_FLAG=true
      shift
      ;;
    --no-color)
      NO_COLOR=true
      setup_colors  # Re-initialize with colors disabled
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
    --worktree)
      WORKTREE_FLAG=true
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
            echo -e "${RED}${E_ERROR} Error: No ralph.json found in $1${NC}"
            exit 1
          fi
        elif [[ -f "$1" ]]; then
          # File given - verify it's ralph.json
          if [[ "$(basename "$1")" != "ralph.json" ]]; then
            echo -e "${RED}${E_ERROR} Error: File must be named ralph.json, got: $1${NC}"
            exit 1
          fi
          RALPH_JSON="$1"
        else
          echo -e "${RED}${E_ERROR} Error: Path not found: $1${NC}"
          exit 1
        fi
        shift
      else
        echo -e "${RED}${E_ERROR} Error: Multiple paths specified${NC}"
        exit 1
      fi
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" && "$TOOL" != "opencode" ]]; then
  echo -e "${RED}${E_ERROR} Error: Invalid tool '$TOOL'. Must be 'amp', 'claude', or 'opencode'.${NC}"
  exit 1
fi

# Check if the selected tool exists
TOOL_CMD="$TOOL"  # Default to the tool name

if [[ -n "$TOOL_PATH" ]]; then
  # Use explicit tool path if provided
  if [[ ! -f "$TOOL_PATH" ]]; then
    echo -e "${RED}${E_ERROR} Error: Tool path not found: $TOOL_PATH${NC}"
    exit 1
  fi
  if [[ ! -x "$TOOL_PATH" ]]; then
    echo -e "${RED}${E_ERROR} Error: Tool path is not executable: $TOOL_PATH${NC}"
    exit 1
  fi
  TOOL_CMD="$TOOL_PATH"
  echo -e "${DIM}Using explicit tool path: $TOOL_PATH${NC}"
elif ! type "$TOOL" &> /dev/null; then
  # Tool not in PATH, check for known fallback locations
  if [[ "$TOOL" == "claude" ]] && [[ -f "$HOME/.claude/local/claude" ]]; then
    echo -e "${DIM}Using local Claude installation: ~/.claude/local/claude${NC}"
    TOOL_CMD="$HOME/.claude/local/claude"
  else
    echo -e "${RED}${E_ERROR} Error: Tool '$TOOL' is not available.${NC}"
    echo "Please install or configure '$TOOL' before running Ralph."
    echo "Alternatively, use --tool-path to specify the exact path to the tool."
    exit 1
  fi
fi

# Validate custom prompt file if provided
if [[ -n "$CUSTOM_PROMPT" ]] && [[ ! -f "$CUSTOM_PROMPT" ]]; then
  echo -e "${RED}${E_ERROR} Error: Custom prompt file not found: $CUSTOM_PROMPT${NC}"
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${RED}${E_ERROR} Error: jq is required but not installed.${NC}"
  echo "Please install jq: https://jqlang.github.io/jq/download/"
  exit 1
fi

# Check if sponge is available
if ! command -v sponge &> /dev/null; then
  echo -e "${RED}${E_ERROR} Error: sponge (from moreutils) is required but not installed.${NC}"
  echo "Install with: brew install moreutils (macOS) or apt-get install moreutils (Ubuntu)"
  exit 1
fi

# If no RALPH_JSON specified, show interactive chooser
if [[ -z "$RALPH_JSON" ]] && [[ "$EJECT_PROMPT_FLAG" != true ]] && [[ "$STATUS_FLAG" != true ]]; then
  # Find all ralph.json files
  mapfile -t RALPH_FILES < <(find ralph -name "ralph.json" -type f 2>/dev/null | grep -v "archive/" | sort)
  
  if [[ ${#RALPH_FILES[@]} -eq 0 ]]; then
    echo -e "${RED}${E_ERROR} Error: No Ralph projects found in ralph/${NC}"
    echo "Use the 'ralph' skill to convert a PRD to ralph.json first."
    exit 1
  fi
  
  # Build menu with completion stats (output to stderr so it doesn't pollute stdout for piping)
  INCOMPLETE_FILES=()
  echo "" >&2
  echo -e "${CYAN}${E_CHART} Available Ralph projects:${NC}" >&2
  echo "" >&2
  
  for i in "${!RALPH_FILES[@]}"; do
    file="${RALPH_FILES[$i]}"
    desc=$(jq -r '.description // "Unknown"' "$file" 2>/dev/null)
    total=$(jq '.userStories | length' "$file" 2>/dev/null || echo "0")
    complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$file" 2>/dev/null || echo "0")
    
    num=$((i + 1))
    
    if [[ "$complete" -eq "$total" ]]; then
      echo -e "  ${GREEN}$num. $desc ($complete/$total complete) ${E_CHECK}${NC}" >&2
    else
      echo -e "  $num. $desc ${DIM}($complete/$total complete)${NC}" >&2
      INCOMPLETE_FILES+=("$file")
    fi
  done
  
  echo "" >&2
  
  # Auto-select if exactly one incomplete
  if [[ ${#INCOMPLETE_FILES[@]} -eq 1 ]]; then
    RALPH_JSON="${INCOMPLETE_FILES[0]}"
    echo -e "${DIM}Auto-selected: $RALPH_JSON${NC}" >&2
    echo "" >&2
  elif [[ ${#INCOMPLETE_FILES[@]} -eq 0 ]]; then
    echo -e "${GREEN}${E_PARTY} All projects complete!${NC}" >&2
    exit 0
  else
    # Prompt for selection
    read -p "Select a project [1-${#RALPH_FILES[@]}]: " selection
    
    if [[ -z "$selection" ]]; then
      echo -e "${RED}${E_ERROR} Error: No selection made${NC}" >&2
      exit 1
    elif [[ ! "$selection" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}${E_ERROR} Error: Selection must be a number${NC}" >&2
      exit 1
    elif [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "${#RALPH_FILES[@]}" ]]; then
      echo -e "${RED}${E_ERROR} Error: Selection out of range (1-${#RALPH_FILES[@]})${NC}" >&2
      exit 1
    fi
    
    RALPH_JSON="${RALPH_FILES[$((selection - 1))]}"
  fi
fi

# Extract directory from ralph.json path
if [[ -n "$RALPH_JSON" ]]; then
  # Convert to absolute path before any directory changes
  RALPH_JSON=$(cd "$(dirname "$RALPH_JSON")" && pwd)/$(basename "$RALPH_JSON")
  RALPH_DIR=$(dirname "$RALPH_JSON")  # e.g., /full/path/to/ralph/auth
  PROGRESS_FILE="$RALPH_DIR/progress.txt"
  ARCHIVE_DIR="ralph/archive"
  LAST_BRANCH_FILE="$RALPH_DIR/.last-branch"
  STOP_FILE="$RALPH_DIR/.ralph-stop"
fi

# Handle --worktree flag (must be before --stop so STOP_FILE path is correct)
if [[ "$WORKTREE_FLAG" == true ]]; then
  if [[ -z "$RALPH_JSON" ]]; then
    echo -e "${RED}${E_ERROR} Error: --worktree requires a ralph project path${NC}"
    exit 1
  fi
  # Store original paths for setup_worktree (called after functions are defined)
  ORIG_RALPH_DIR="$RALPH_DIR"
  ORIG_RALPH_JSON="$RALPH_JSON"
fi

# Handle --stop flag now that we know the directory
if [[ "$STOP_FLAG" == true ]]; then
  if [[ -z "$RALPH_JSON" ]]; then
    echo -e "${RED}${E_ERROR} Error: --stop requires a ralph project path${NC}"
    exit 1
  fi
  touch "$STOP_FILE"
  echo -e "${YELLOW}${E_STOP} Stop signal sent. Ralph will stop before the next iteration.${NC}"
  exit 0
fi

# Helper function to initialize progress file header
init_progress_header() {
  local ralph_json="$1"
  local tool="$2"
  local tool_args="$3"

  echo "# Ralph Progress Log"
  echo "Started: $(date '+%Y-%m-%d %H:%M')"

  # Extract and add source from ralph.json if present
  if [ -f "$ralph_json" ]; then
    local source=$(jq -r '.source // empty' "$ralph_json" 2>/dev/null || echo "")
    if [[ -n "$source" ]]; then
      echo "Source PRD: $source"
    fi
  fi

  echo "---"
}

# Ensure .worktrees/ is in .gitignore
ensure_gitignore_worktrees() {
  if ! grep -q "^\.worktrees/$" .gitignore 2>/dev/null; then
    echo ".worktrees/" >> .gitignore
    echo -e "${DIM}Added .worktrees/ to .gitignore${NC}"
  fi
}

# Setup git worktree for isolated execution
setup_worktree() {
  local abs_ralph_dir="$1"  # Absolute path to ralph dir
  local abs_ralph_json="$2"  # Absolute path to ralph.json

  # Extract relative ralph path (e.g., /full/path/ralph/auth -> ralph/auth)
  local rel_ralph_dir=$(echo "$abs_ralph_dir" | sed 's|.*/\(ralph/[^/]*\)$|\1|')

  # Extract feature name from ralph_dir (e.g., ralph/auth -> auth)
  local feature_name=$(basename "$abs_ralph_dir")

  # Read branch name from ralph.json
  local branch_name=$(jq -r '.branchName' "$abs_ralph_json")
  if [[ -z "$branch_name" || "$branch_name" == "null" ]]; then
    echo -e "${RED}${E_ERROR} Error: No branchName in $abs_ralph_json${NC}"
    exit 1
  fi
  
  # Ensure .worktrees/ is gitignored
  ensure_gitignore_worktrees
  
  # Set worktree path
  WORKTREE_DIR="$WORKTREE_BASE/$feature_name"
  
  # Handle existing worktree
  if [[ -d "$WORKTREE_DIR" ]]; then
    echo ""
    echo -e "${YELLOW}${E_WARN}Worktree already exists: $WORKTREE_DIR${NC}"
    read -p "Reuse existing worktree? [y/N]: " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo -e "${RED}${E_ERROR} Aborted. Remove worktree manually:${NC}"
      echo "  git worktree remove $WORKTREE_DIR"
      exit 1
    fi
    echo -e "${DIM}Reusing existing worktree (preserving progress)...${NC}"
  else
    # Create worktree base directory
    mkdir -p "$WORKTREE_BASE"

    # Try to add worktree on existing branch, or create new branch
    echo -e "${DIM}Creating worktree at $WORKTREE_DIR on branch $branch_name...${NC}"
    if ! git worktree add "$WORKTREE_DIR" "$branch_name" 2>/dev/null; then
      # Branch doesn't exist, create it from current HEAD
      git worktree add -b "$branch_name" "$WORKTREE_DIR"
    fi

    # Copy ralph project files to worktree (only for NEW worktrees)
    echo -e "${DIM}Copying ralph files to worktree...${NC}"

    # Verify source ralph.json exists before copying
    if [[ ! -f "$abs_ralph_json" ]]; then
      echo -e "${RED}${E_ERROR} Error: Source ralph.json not found at $abs_ralph_json${NC}"
      exit 1
    fi

    # Create worktree directory structure using relative path
    mkdir -p "$WORKTREE_DIR/$rel_ralph_dir"

    # Copy from absolute source path to worktree
    cp -r "$abs_ralph_dir"/* "$WORKTREE_DIR/$rel_ralph_dir/" 2>/dev/null || cp -r "$abs_ralph_dir"/. "$WORKTREE_DIR/$rel_ralph_dir/"
  fi

  # Update all paths to point to worktree (using relative paths within worktree)
  RALPH_JSON="$WORKTREE_DIR/$rel_ralph_dir/ralph.json"
  RALPH_DIR="$WORKTREE_DIR/$rel_ralph_dir"

  # Verify ralph.json exists in worktree
  if [[ ! -f "$RALPH_JSON" ]]; then
    echo -e "${RED}${E_ERROR} Error: ralph.json not found in worktree${NC}"
    echo -e "${DIM}Expected at: $RALPH_JSON${NC}"
    exit 1
  fi
  PROGRESS_FILE="$RALPH_DIR/progress.txt"
  LEARNINGS_FILE="$RALPH_DIR/AGENTS.md"
  LAST_BRANCH_FILE="$RALPH_DIR/.last-branch"
  STOP_FILE="$RALPH_DIR/.ralph-stop"
  ARCHIVE_DIR="$WORKTREE_DIR/ralph/archive"

  echo -e "${GREEN}${E_CHECK} Worktree ready:${NC} $WORKTREE_DIR"

  # Save relative path for display purposes
  WORKTREE_DIR_RELATIVE="$WORKTREE_DIR"

  # Convert to absolute path before changing directory
  WORKTREE_DIR=$(cd "$WORKTREE_DIR" && pwd)

  # Change to worktree directory so tools operate there
  cd "$WORKTREE_DIR" || {
    echo -e "${RED}${E_ERROR} Failed to cd to worktree: $WORKTREE_DIR${NC}"
    exit 1
  }

  # Update paths to be relative to the worktree working directory
  RALPH_JSON="$rel_ralph_dir/ralph.json"
  RALPH_DIR="$rel_ralph_dir"
  PROGRESS_FILE="$RALPH_DIR/progress.txt"
  LEARNINGS_FILE="$RALPH_DIR/AGENTS.md"
  LAST_BRANCH_FILE="$RALPH_DIR/.last-branch"
  STOP_FILE="$RALPH_DIR/.ralph-stop"
  ARCHIVE_DIR="ralph/archive"
}

# Generate the prompt with pre-computed variables
# All variables are substituted at runtime before this function is called
generate_prompt() {
  local tool="$1"
  local story_id="$2"
  local story_title="$3"
  local story_description="$4"
  local story_criteria="$5"
  local primary_plan_path="$6"
  local story_plan_path="$7"
  local learnings_file_exists="$8"
  local branch_name="$9"
  local update_story_cmd="${10}"
  local ralph_dir="${11}"
  local ralph_json="${12}"
  local progress_file="${13}"
  local learnings_file="${14}"
  local is_last_story="${15}"
  local learn_flag="${16}"
  
  # Build the prompt
  cat << PROMPT_HEADER
# Ralph Agent Task

## Current Story: $story_id - $story_title

$story_description

### Acceptance Criteria
$story_criteria

### Context Files
- Primary plan: \`$primary_plan_path\`
PROMPT_HEADER

  # Story plan line (only if story has source field)
  if [[ -n "$story_plan_path" ]]; then
    echo "- Story details: \`$story_plan_path\`"
  fi

  # Learnings file reference (only if file exists and has >2 lines)
  if [[ "$learnings_file_exists" == "true" ]]; then
    echo "- Memory from previous iterations: \`$learnings_file\`"
  fi

  cat << 'PROMPT_INSTRUCTIONS'

---

## Instructions

1. **Read context**: Load the Context Files listed above

2. **Implement** the story, meeting all acceptance criteria

3. **Run quality checks** (typecheck, lint, test - whatever the project requires)

4. **Complete the story** - Do ALL of the following before committing:
   a. Update ralph.json to mark story complete
   b. Append progress entry to progress.txt
PROMPT_INSTRUCTIONS

  echo "   c. Record learnings (if any) to \`$learnings_file\`"
  cat << 'PROMPT_INSTRUCTIONS_CONT'
   d. Stage ALL changes (implementation + bookkeeping files)

5. **Commit** with message starting:
PROMPT_INSTRUCTIONS_CONT

  echo "      \`feat: $story_id - $story_title\`"
  cat << 'PROMPT_INSTRUCTIONS2'
   
   This atomic commit ensures bookkeeping is never forgotten.
   
Commands:
PROMPT_INSTRUCTIONS2

  echo "   \`\`\`bash"
  echo "   # a. Mark story complete"
  echo "   $update_story_cmd"
  echo ""
  echo "   # b. Append progress"
  echo "   cat >> \"$progress_file\" << 'PROGRESS_ENTRY'"
  echo "   ### [\$(date '+%Y-%m-%d %H:%M')] - $story_id"
  
  # Thread URL line (only for Amp)
  if [[ "$tool" == "amp" ]]; then
    echo "   Thread: https://ampcode.com/threads/\$AMP_CURRENT_THREAD_ID"
  fi
  
  echo "   Implemented: [1-2 sentence summary]"
  echo "   Files changed:"
  echo "   - path/to/file.ts (created/modified/deleted)"
  echo "   ---"
  echo "   PROGRESS_ENTRY"
  echo ""
  echo "   # c. Record learnings (if any patterns/gotchas discovered)"
  echo "   echo '[Your learning here]' >> \"$learnings_file\""
  echo "   \`\`\`"

  echo ""

  # Thread URL note (only for Amp)
  if [[ "$tool" == "amp" ]]; then
    cat << 'AMP_THREAD_NOTE'

Include Amp thread URL in progress log: https://ampcode.com/threads/$AMP_CURRENT_THREAD_ID
AMP_THREAD_NOTE
  fi

  # Cleanup section (only if last story)
  if [[ "$is_last_story" == "true" ]]; then
    cat << CLEANUP_SECTION

## Final Cleanup (Last Story!)

This is the last story. After completing it:

1. Run cleanup:
   \`\`\`bash
   git rm --cached -r "$ralph_dir"
   git commit -m "chore: cleanup $ralph_dir working files"
   \`\`\`

2. Reply with: \`<promise>COMPLETE</promise>\`
CLEANUP_SECTION
  fi

  # Learn section (only if --learn flag and last story)
  if [[ "$learn_flag" == "true" && "$is_last_story" == "true" ]]; then
    cat << LEARN_SECTION

## Absorb Learnings

Read \`$learnings_file\` and merge valuable learnings into \`./AGENTS.md\` (project root):
- Deduplicate with existing entries
- Group related learnings together  
- Remove feature-specific details that won't apply to future work
- Keep learnings that would help future development in this codebase
LEARN_SECTION
  fi

  cat << 'QUALITY_REQUIREMENTS'

## Quality Requirements
- All commits must pass quality checks
- Keep changes focused and minimal
- Follow existing code patterns
QUALITY_REQUIREMENTS
}

# Generate learn-only prompt
generate_learn_prompt() {
  local learnings_file="$1"
  local learnings_content="$2"
  
  cat << LEARN_PROMPT
# Absorb Learnings

Read the following learnings and merge them into \`./AGENTS.md\` (project root):

## Learnings from $learnings_file

$learnings_content

## Instructions

1. Read \`./AGENTS.md\` if it exists
2. Merge valuable learnings:
   - Deduplicate with existing entries
   - Group related learnings together  
   - Remove feature-specific details that won't apply to future work
   - Keep learnings that would help future development in this codebase
3. Write the updated file

Reply with: \`<promise>COMPLETE</promise>\` when done.
LEARN_PROMPT
}

# Handle --eject-prompt flag (now that generate_prompt is defined)
# This creates a reusable template in .agents/ralph.md (current directory)
# No project path required - outputs template with $VARIABLE placeholders
if [ "$EJECT_PROMPT_FLAG" = true ]; then
  EJECT_DIR=".agents"
  EJECT_FILE="$EJECT_DIR/ralph.md"
  
  if [ -f "$EJECT_FILE" ]; then
    echo -e "${RED}${E_ERROR} Error: $EJECT_FILE already exists.${NC}"
    echo "Delete it first if you want to regenerate it."
    exit 1
  fi
  
  mkdir -p "$EJECT_DIR"
  
  # Generate template with $VARIABLE placeholders (not substituted)
  cat > "$EJECT_FILE" << 'TEMPLATE_EOF'
<!-- Ralph Prompt Template

Available variables (substituted at runtime):
  $RALPH_DIR          - Ralph project directory (e.g., ralph/auth)
  $RALPH_JSON         - Path to ralph.json
  $PROGRESS_FILE      - Path to progress.txt
  $LEARNINGS_FILE     - Path to AGENTS.md in ralph dir
  $BRANCH_NAME        - Git branch name
  $STORY_ID           - Current story ID (e.g., US-001)
  $STORY_TITLE        - Current story title
  $STORY_DESCRIPTION  - Current story description (not directly available in template)
  $STORY_CRITERIA     - Acceptance criteria as bullet list (not directly available)
  $PRIMARY_PLAN_PATH  - Path to README.md
  $STORY_PLAN_PATH    - Path to story-specific plan (if exists)
  $UPDATE_STORY_CMD   - Command to mark story complete (not directly available)

Note: Some variables like $STORY_DESCRIPTION, $STORY_CRITERIA, and $UPDATE_STORY_CMD
are only available in the embedded prompt, not in custom templates. Custom templates 
receive the simpler variables via sed substitution.

To use this template:
  1. Copy to your ralph project: cp .agents/ralph.md ralph/myproject/.agents/
  2. Edit as needed
  3. Ralph will automatically use it when running that project

-->

# Ralph Agent Task

## Current Story: $STORY_ID - $STORY_TITLE

Read the story details from ralph.json:
```bash
jq '[.userStories[] | select(.passes == false)] | min_by(.priority)' "$RALPH_JSON"
```

### Context Files
- Primary plan: `$PRIMARY_PLAN_PATH`
- Story details: `$STORY_PLAN_PATH`
- Learnings: `$LEARNINGS_FILE`

---

## Instructions

1. **Read context**: Load the plan files and story details from ralph.json

2. **Implement** the story, meeting all acceptance criteria

3. **Run quality checks** (typecheck, lint, test - whatever the project requires)

4. **Complete the story** - Do ALL of the following before committing:
   a. Update ralph.json to mark story complete
   b. Append progress entry to progress.txt
   c. Record learnings (if any) to `$LEARNINGS_FILE`
   d. Stage ALL changes (implementation + bookkeeping files)

5. **Commit** with message starting: `feat: $STORY_ID - $STORY_TITLE`
   
   This atomic commit ensures bookkeeping is never forgotten.
   
Commands:
   ```bash
   # a. Mark story complete
   jq '(.userStories[] | select(.id == "'\"$STORY_ID\"'") | .passes) = true' "$RALPH_JSON" > "$RALPH_JSON.tmp" && mv "$RALPH_JSON.tmp" "$RALPH_JSON"
   
   # b. Append progress
   cat >> "$PROGRESS_FILE" << 'PROGRESS_ENTRY'
   ### [$(date '+%Y-%m-%d %H:%M')] - $STORY_ID
   Implemented: [1-2 sentence summary]
   Files changed:
   - path/to/file.ts (created/modified/deleted)
   ---
   PROGRESS_ENTRY
   
   # c. Record learnings (if any patterns/gotchas discovered)
   echo '[Your learning here]' >> "$LEARNINGS_FILE"
   ```

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`:

```bash
jq 'all(.userStories[]; .passes == true)' "$RALPH_JSON"
```

If ALL stories are complete:

1. **Perform cleanup commit**:
   ```bash
   git rm --cached -r "$RALPH_DIR"
   git commit -m "chore: cleanup $RALPH_DIR working files"
   ```

2. Reply with: `<promise>COMPLETE</promise>`

## Quality Requirements
- All commits must pass quality checks
- Keep changes focused and minimal
- Follow existing code patterns
TEMPLATE_EOF
  
  echo -e "${GREEN}${E_CHECK} Created${NC} $EJECT_FILE"
  echo ""
  echo "To use this template:"
  echo "  1. Copy to your ralph project: cp $EJECT_FILE ralph/myproject/.agents/"
  echo "  2. Edit as needed"
  echo "  3. Ralph will automatically use it"
  exit 0
fi

# Pre-compute variables function (used by --next-prompt and main loop)
precompute_variables() {
  # Pre-compute from ralph.json
  BRANCH_NAME=$(jq -r '.branchName' "$RALPH_JSON")
  PRIMARY_PLAN_PATH=$(jq -r '.source' "$RALPH_JSON")

  # Current story details
  CURRENT_STORY=$(jq '[.userStories[] | select(.passes == false)] | min_by(.priority)' "$RALPH_JSON")
  STORY_ID=$(echo "$CURRENT_STORY" | jq -r '.id')
  STORY_TITLE=$(echo "$CURRENT_STORY" | jq -r '.title')
  STORY_DESCRIPTION=$(echo "$CURRENT_STORY" | jq -r '.description')
  STORY_CRITERIA=$(echo "$CURRENT_STORY" | jq -r '.acceptanceCriteria[]' | sed 's/^/- /')
  STORY_PLAN_PATH=$(echo "$CURRENT_STORY" | jq -r '.source // empty')

  # Counts
  STORIES_REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$RALPH_JSON")
  IS_LAST_STORY=$([[ "$STORIES_REMAINING" -eq 1 ]] && echo "true" || echo "false")

  # Learnings file
  LEARNINGS_FILE="$RALPH_DIR/AGENTS.md"
  # Check if learnings file exists and has meaningful content (>2 lines)
  if [[ -f "$LEARNINGS_FILE" ]] && [[ $(wc -l < "$LEARNINGS_FILE") -gt 2 ]]; then
    LEARNINGS_FILE_EXISTS="true"
  else
    LEARNINGS_FILE_EXISTS="false"
  fi

  # Pre-built update command
  UPDATE_STORY_CMD="jq '(.userStories[] | select(.id == \"$STORY_ID\") | .passes) = true' \"$RALPH_JSON\" > \"$RALPH_JSON.tmp\" && mv \"$RALPH_JSON.tmp\" \"$RALPH_JSON\""
}

# Auto-create AGENTS.md function
ensure_learnings_file() {
  if [[ ! -f "$LEARNINGS_FILE" ]]; then
    FEATURE_NAME=$(jq -r '.description // "Feature"' "$RALPH_JSON")
    cat > "$LEARNINGS_FILE" << EOF
# $FEATURE_NAME - Learnings

EOF
  fi
}

# Format seconds to human-readable time (e.g., "2m 15s", "1h 5m 32s")
# Args: seconds
format_time() {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(( (total_seconds % 3600) / 60 ))
  local seconds=$((total_seconds % 60))
  
  if [[ $hours -gt 0 ]]; then
    echo "${hours}h ${minutes}m ${seconds}s"
  elif [[ $minutes -gt 0 ]]; then
    echo "${minutes}m ${seconds}s"
  else
    echo "${seconds}s"
  fi
}

# Monitor a process and display real-time stats
# Args: PID, START_TIME, [OPENCODE_PORT]
monitor_process() {
  local pid=$1
  local start_time=$2
  local opencode_port=$3
  local last_line=""
  
  # Skip monitoring if stderr is not a TTY (e.g., piped to file)
  if [[ ! -t 2 ]]; then
    return 0
  fi
  
  # Check if process exists before starting monitoring
  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  while kill -0 "$pid" 2>/dev/null; do
    # Calculate elapsed time
    local elapsed=$(($(date +%s) - start_time))
    local elapsed_str=$(format_time $elapsed)
    
    # Get CPU usage via ps
    local cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0")
    
    # Get memory usage (RSS in MB)
    local mem_kb=$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ' || echo "0")
    local mem_mb=$((mem_kb / 1024))
    
    # Get LISTENING ports (use OpenCode port if provided, otherwise detect)
    local ports=""
    local port_label="Ports"
    if [[ -n "$opencode_port" ]]; then
      # Use OpenCode server URL for clickable link
      ports="http://localhost:$opencode_port"
      port_label="Web GUI"
    elif command -v ss &>/dev/null; then
      # Use ss to get listening ports for this PID
      ports=$(ss -ltnp 2>/dev/null | grep "pid=$pid," | awk '{print $4}' | sed 's/.*://' | sort -u | tr '\n' ',' | sed 's/,$//')
      [[ -z "$ports" ]] && ports="none"
    elif command -v netstat &>/dev/null; then
      # Fallback to netstat
      ports=$(netstat -ltnp 2>/dev/null | grep "$pid/" | awk '{print $4}' | sed 's/.*://' | sort -u | tr '\n' ',' | sed 's/,$//')
      [[ -z "$ports" ]] && ports="none"
    else
      ports="none"
    fi

    # Build status line with elapsed time (no colors for cleaner display)
    local status_line="[Monitor] Agent PID: ${pid} | Elapsed: ${elapsed_str} | CPU: ${cpu}% | MEM: ${mem_mb}MB | ${port_label}: ${ports}"
    
    # Only update if changed (reduce flicker)
    if [[ "$status_line" != "$last_line" ]]; then
      # Save cursor position, move to first line, write status, restore cursor
      printf "\033[s\033[1;1H\033[K%s\033[u" "$status_line" >&2
      last_line="$status_line"
    fi
    
    sleep 1
  done
  
  # Clear monitoring line when process ends
  printf "\033[s\033[1;1H\033[K\033[u" >&2
}

# Display final wall time summary
# Args: none (uses global RALPH_START_TIME)
show_final_wall_time() {
  # Show git stats for the last commit
  echo ""
  git show --stat
  echo ""

  local ralph_end_time=$(date +%s)
  local total_wall_time=$((ralph_end_time - RALPH_START_TIME))
  local wall_time_str=$(format_time $total_wall_time)
  echo -e "${DIM}Total wall time: ${wall_time_str}${NC}"
}

# Actually setup worktree now that functions are defined
if [[ "$WORKTREE_FLAG" == true ]]; then
  setup_worktree "$ORIG_RALPH_DIR" "$ORIG_RALPH_JSON"
fi

# Handle --next-prompt flag
# Headers go to stderr so prompt content can be piped to an agent
if [[ "$NEXT_PROMPT_FLAG" = true ]]; then
  if [[ -z "$RALPH_JSON" ]]; then
    echo -e "${RED}${E_ERROR} Error: --next-prompt requires a ralph project path${NC}" >&2
    exit 1
  fi
  
  # Pre-compute all variables
  precompute_variables
  
  # Check if all stories already complete
  ALL_COMPLETE=$(jq 'all(.userStories[]; .passes == true)' "$RALPH_JSON" 2>/dev/null || echo "false")
  
  if [[ "$ALL_COMPLETE" == "true" ]]; then
    if [[ "$LEARN_FLAG" == "true" || "$LEARN_NOW_FLAG" == "true" ]]; then
      echo -e "${CYAN}========== LEARN PROMPT ==========${NC}" >&2
      generate_learn_prompt "$LEARNINGS_FILE" "$CODEBASE_PATTERNS"
    else
      echo -e "${GREEN}${E_PARTY} All stories complete! Nothing to do.${NC}" >&2
    fi
    exit 0
  fi
  
  # Handle --learn-now (just show learn prompt)
  if [[ "$LEARN_NOW_FLAG" == "true" ]]; then
    if [[ -z "$CODEBASE_PATTERNS" ]]; then
      echo -e "${RED}${E_ERROR} Error: No learnings file found or file is empty at $LEARNINGS_FILE${NC}" >&2
      exit 1
    fi
    echo -e "${CYAN}========== LEARN PROMPT ==========${NC}" >&2
    generate_learn_prompt "$LEARNINGS_FILE" "$CODEBASE_PATTERNS"
    exit 0
  fi
  
  echo -e "${CYAN}========== PROMPT (with pre-computed variables) ==========${NC}" >&2
  # Show the prompt with all variables
  if [[ -n "$CUSTOM_PROMPT" ]]; then
    # For custom prompts, still use sed substitution
    sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
        -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
        -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g" \
        -e "s|\\\$LEARNINGS_FILE|$LEARNINGS_FILE|g" \
        -e "s|\\\$BRANCH_NAME|$BRANCH_NAME|g" \
        -e "s|\\\$STORY_ID|$STORY_ID|g" \
        -e "s|\\\$STORY_TITLE|$STORY_TITLE|g" \
        "$CUSTOM_PROMPT"
  elif [[ -f "$RALPH_DIR/.agents/ralph.md" ]]; then
    sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
        -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
        -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g" \
        -e "s|\\\$LEARNINGS_FILE|$LEARNINGS_FILE|g" \
        -e "s|\\\$BRANCH_NAME|$BRANCH_NAME|g" \
        -e "s|\\\$STORY_ID|$STORY_ID|g" \
        -e "s|\\\$STORY_TITLE|$STORY_TITLE|g" \
        "$RALPH_DIR/.agents/ralph.md"
  else
    generate_prompt "$TOOL" \
      "$STORY_ID" \
      "$STORY_TITLE" \
      "$STORY_DESCRIPTION" \
      "$STORY_CRITERIA" \
      "$PRIMARY_PLAN_PATH" \
      "$STORY_PLAN_PATH" \
      "$LEARNINGS_FILE_EXISTS" \
      "$BRANCH_NAME" \
      "$UPDATE_STORY_CMD" \
      "$RALPH_DIR" \
      "$RALPH_JSON" \
      "$PROGRESS_FILE" \
      "$LEARNINGS_FILE" \
      "$IS_LAST_STORY" \
      "$LEARN_FLAG"
  fi
  
  exit 0
fi

# Handle --status flag
if [[ "$STATUS_FLAG" = true ]]; then
  if [[ -z "$RALPH_JSON" ]]; then
    echo -e "${RED}${E_ERROR} Error: --status requires a ralph project path${NC}" >&2
    exit 1
  fi
  
  # Read data from ralph.json
  PROJECT=$(jq -r '.project // "Unknown"' "$RALPH_JSON")
  DESCRIPTION=$(jq -r '.description // "No description"' "$RALPH_JSON")
  BRANCH_NAME=$(jq -r '.branchName // "Unknown"' "$RALPH_JSON")
  SOURCE_PRD=$(jq -r '.source // "Unknown"' "$RALPH_JSON")
  
  # Get started date from progress.txt if it exists
  STARTED=""
  if [[ -f "$PROGRESS_FILE" ]]; then
    STARTED=$(grep -m1 "^Started:" "$PROGRESS_FILE" 2>/dev/null | sed 's/Started: //' || echo "")
  fi
  
  # Count stories
  TOTAL_STORIES=$(jq '.userStories | length' "$RALPH_JSON")
  COMPLETE_STORIES=$(jq '[.userStories[] | select(.passes == true)] | length' "$RALPH_JSON")
  PERCENT=$((COMPLETE_STORIES * 100 / TOTAL_STORIES))
  
  # Print header
  echo ""
  echo -e "${CYAN}${E_CHART} Ralph Status: ${BOLD}$RALPH_DIR${NC}"
  echo -e "${DIM}═════════════════════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${DIM}Project:${NC}     $PROJECT"
  echo -e "  ${DIM}Description:${NC} $DESCRIPTION"
  echo -e "  ${DIM}Branch:${NC}      $BRANCH_NAME"
  echo -e "  ${DIM}Source PRD:${NC}  $SOURCE_PRD"
  if [[ -n "$STARTED" ]]; then
    echo -e "  ${DIM}Started:${NC}     $STARTED"
  fi
  echo ""
  echo -e "${DIM}─────────────────────────────────────────────────────────────────────────────${NC}"
  echo -e "  ${BOLD}User Stories${NC}"
  echo -e "${DIM}─────────────────────────────────────────────────────────────────────────────${NC}"
  echo ""
  
  # Print each story
  jq -r '.userStories[] | "\(.passes)\t\(.id)\t\(.title)"' "$RALPH_JSON" | while IFS=$'\t' read -r passes id title; do
    if [[ "$passes" == "true" ]]; then
      echo -e "  ${GREEN}${E_BOX_CHECK}${NC} ${DIM}$id${NC} - $title"
    else
      echo -e "  ${E_BOX_EMPTY} ${DIM}$id${NC} - $title"
    fi
  done
  
  echo ""
  echo -e "${DIM}─────────────────────────────────────────────────────────────────────────────${NC}"
  
  # Print progress summary with color based on completion
  if [[ "$PERCENT" -eq 100 ]]; then
    echo -e "  ${GREEN}${E_PARTY} Progress: $COMPLETE_STORIES/$TOTAL_STORIES stories complete (${PERCENT}%)${NC}"
  elif [[ "$PERCENT" -ge 50 ]]; then
    echo -e "  ${CYAN}Progress: $COMPLETE_STORIES/$TOTAL_STORIES stories complete (${PERCENT}%)${NC}"
  else
    echo -e "  Progress: $COMPLETE_STORIES/$TOTAL_STORIES stories complete (${PERCENT}%)"
  fi
  
  echo -e "${DIM}═════════════════════════════════════════════════════════════════════════════${NC}"
  echo ""
  
  exit 0
fi

# Validate ralph.json exists
if [[ -z "$RALPH_JSON" ]] || [[ ! -f "$RALPH_JSON" ]]; then
  echo -e "${RED}${E_ERROR} Error: ralph.json not found.${NC}"
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
    
    echo -e "${DIM}${E_FOLDER} Archiving previous run: $LAST_BRANCH${NC}"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$RALPH_JSON" ] && cp "$RALPH_JSON" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo -e "${DIM}   Archived to: $ARCHIVE_FOLDER${NC}"

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

# Initialize learnings file path (will be created on first task)
LEARNINGS_FILE="$RALPH_DIR/AGENTS.md"

# Function to start OpenCode server (called when needed)
start_opencode_server() {
  if [[ "$TOOL" != "opencode" ]] || [[ -n "$OPENCODE_SERVER_PID" ]]; then
    return 0
  fi
  
  # Generate random high port (49152-65535 is the dynamic/private port range)
  OPENCODE_PORT=$((49152 + RANDOM % 16384))
  OPENCODE_URL="http://127.0.0.1:$OPENCODE_PORT"
  
  echo -e "   ${DIM}Starting OpenCode server on port $OPENCODE_PORT...${NC}"
  
  # Start the server in background
  "$TOOL_CMD" serve --port "$OPENCODE_PORT" > /dev/null 2>&1 &
  OPENCODE_SERVER_PID=$!
  
  # Wait for server to be ready (max 5 seconds)
  local wait_start=$(date +%s)
  local server_ready=false
  while [[ $(($(date +%s) - wait_start)) -lt 5 ]]; do
    if curl -s --max-time 1 "$OPENCODE_URL/health" > /dev/null 2>&1 || \
       wget -q --timeout=1 -O /dev/null "$OPENCODE_URL/health" 2>/dev/null; then
      server_ready=true
      break
    fi
    sleep 0.2
  done
  
  if [[ "$server_ready" != "true" ]]; then
    echo -e "${RED}${E_ERROR} Error: OpenCode server failed to start on port $OPENCODE_PORT${NC}"
    # Kill the server process if it's still there
    if kill -0 "$OPENCODE_SERVER_PID" 2>/dev/null; then
      kill "$OPENCODE_SERVER_PID" 2>/dev/null || true
    fi
    OPENCODE_SERVER_PID=""
    exit 1
  fi
}

# Handle --learn-now flag (just run learn prompt, no tasks)
if [[ "$LEARN_NOW_FLAG" == "true" ]]; then
  if [[ ! -f "$LEARNINGS_FILE" ]] || [[ ! -s "$LEARNINGS_FILE" ]]; then
    echo -e "${RED}${E_ERROR} Error: No learnings file found at $LEARNINGS_FILE${NC}"
    exit 1
  fi
  
  # Start OpenCode server if needed
  start_opencode_server
  
  # Initialize wall time tracking
  RALPH_START_TIME=$(date +%s)
  
  CODEBASE_PATTERNS=$(cat "$LEARNINGS_FILE")
  PROMPT=$(generate_learn_prompt "$LEARNINGS_FILE" "$CODEBASE_PATTERNS")

  # Debug: Write prompt to file for inspection
  if [[ -n "$DEBUG" ]]; then
    DEBUG_PROMPT_FILE="$RALPH_DIR/DEBUG-generated-prompt.md"
    {
      echo "# Debug: Learn-Only Prompt"
      echo ""
      echo "## Environment Info"
      echo "- Current directory: $(pwd)"
      echo "- RALPH_DIR: $RALPH_DIR"
      echo "- LEARNINGS_FILE: $LEARNINGS_FILE"
      echo ""
      echo "---"
      echo ""
      echo "$PROMPT"
    } > "$DEBUG_PROMPT_FILE"
    echo -e "${DIM}Debug: Prompt written to $DEBUG_PROMPT_FILE${NC}"
  fi

  echo -e "${CYAN}${E_BOOK} Running learn-only prompt...${NC}"
  
  # Record start time
  LEARN_START=$(date +%s)
  
  # Create temp file for output capture
  TEMP_OUTPUT=$(mktemp)
  
  [[ -n "$DEBUG" ]] && echo "[DEBUG] Working directory: $(pwd)"

  # Run the tool with learn prompt (redirect output to file)
  if [[ "$TOOL" == "amp" ]]; then
    echo "$PROMPT" | "$TOOL_CMD" --dangerously-allow-all "${TOOL_ARGS[@]}" > "$TEMP_OUTPUT" 2>&1 &
    TOOL_PID=$!
  elif [[ "$TOOL" == "claude" ]]; then
    echo "$PROMPT" | "$TOOL_CMD" --dangerously-skip-permissions --print "${TOOL_ARGS[@]}" > "$TEMP_OUTPUT" 2>&1 &
    TOOL_PID=$!
  else
    # OpenCode: use run command with --attach to connect to server
    if ((${#TOOL_ARGS[@]})); then
      "$TOOL_CMD" run --attach "$OPENCODE_URL" "$PROMPT" "${TOOL_ARGS[@]}" > "$TEMP_OUTPUT" 2>&1 &
    else
      "$TOOL_CMD" run --attach "$OPENCODE_URL" "$PROMPT" > "$TEMP_OUTPUT" 2>&1 &
    fi
    TOOL_PID=$!
  fi
  
  # Stream output file to terminal using tail -f
  tail -f "$TEMP_OUTPUT" 2>/dev/null &
  TAIL_PID=$!

  # Start monitoring in background
  monitor_process "$TOOL_PID" "$LEARN_START" "$OPENCODE_PORT" &
  MONITOR_PID=$!
  
  # Wait for tool to complete
  wait "$TOOL_PID" || true
  
  # Stop tail and monitoring
  kill "$TAIL_PID" 2>/dev/null || true
  wait "$TAIL_PID" 2>/dev/null || true
  kill "$MONITOR_PID" 2>/dev/null || true
  wait "$MONITOR_PID" 2>/dev/null || true
  
  # Check for completion signal and cleanup temp file
  if grep -q "<promise>COMPLETE</promise>" "$TEMP_OUTPUT"; then
    echo ""
    echo -e "${GREEN}${E_SPARKLE} Learnings absorbed successfully!${NC}"
  fi
  rm -f "$TEMP_OUTPUT"
  show_final_wall_time
  exit 0
fi

# Check for project-local prompt template and show message once
if [[ -z "$CUSTOM_PROMPT" ]] && [[ -f "$RALPH_DIR/.agents/ralph.md" ]]; then
  echo -e "${CYAN}${E_FILE} Using project-local prompt:${NC} $RALPH_DIR/.agents/ralph.md"
fi

# Set up scrolling region for monitor (reserve line 1 for status bar)
if [[ -t 2 ]]; then
  TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
  printf "\033[2J\033[H\033[2;%dr\033[2;1H" "$TERM_HEIGHT" >&2
fi

echo ""
echo -e "${CYAN}${E_ROCKET} Starting Ralph${NC}"
echo -e "   ${DIM}Project:${NC}        ${ORIG_RALPH_DIR:-$RALPH_DIR}"

# Start OpenCode server if using opencode (but NOT if worktree mode - will start later)
if [[ "$WORKTREE_FLAG" != true ]]; then
  start_opencode_server
fi

# Display tool info
if [[ "$TOOL" == "opencode" ]] && [[ -n "$OPENCODE_PORT" ]]; then
  if ((${#TOOL_ARGS[@]})); then
    echo -e "   ${DIM}Tool:${NC}           $TOOL (server port $OPENCODE_PORT) ${TOOL_ARGS[*]}"
  else
    echo -e "   ${DIM}Tool:${NC}           $TOOL (server port $OPENCODE_PORT)"
  fi
elif ((${#TOOL_ARGS[@]})); then
  echo -e "   ${DIM}Tool:${NC}           $TOOL ${TOOL_ARGS[*]}"
else
  echo -e "   ${DIM}Tool:${NC}           $TOOL"
fi

echo -e "   ${DIM}Max iterations:${NC} $MAX_ITERATIONS"
if [[ -n "$ORIG_RALPH_DIR" ]]; then
  echo -e "   ${DIM}Working dir:${NC}    $(pwd)"
fi

# Failure tracking for circuit breaker
CONSECUTIVE_FAILURES=0
MAX_FAILURES=5
MIN_ITERATION_TIME=4  # seconds - iterations faster than this are considered failures

# Wall time tracking
RALPH_START_TIME=$(date +%s)
TOTAL_ITERATION_TIME=0

# Checkout the branch once before starting iterations
BRANCH_NAME=$(jq -r '.branchName' "$RALPH_JSON")
if [[ -n "$BRANCH_NAME" && "$BRANCH_NAME" != "null" ]]; then
  echo ""
  echo -e "${CYAN}${E_ROCKET} Checking out branch: $BRANCH_NAME${NC}"
  if git checkout "$BRANCH_NAME" 2>/dev/null; then
    echo -e "${DIM}   Already on branch $BRANCH_NAME${NC}"
  else
    git checkout -b "$BRANCH_NAME"
    echo -e "${DIM}   Created new branch $BRANCH_NAME${NC}"
  fi
fi

for i in $(seq 1 $MAX_ITERATIONS); do
  # Ensure we're in the correct working directory (especially important for worktrees)
  if [[ "$WORKTREE_FLAG" == true ]] && [[ -n "$WORKTREE_DIR" ]]; then
    cd "$WORKTREE_DIR" || {
      echo -e "${RED}${E_ERROR} Failed to cd back to worktree: $WORKTREE_DIR${NC}"
      exit 1
    }

    # Start OpenCode server NOW (after cd) so it inherits correct working directory
    # Only starts if not already started (start_opencode_server checks OPENCODE_SERVER_PID)
    if [[ "$TOOL" == "opencode" ]] && [[ -z "$OPENCODE_SERVER_PID" ]]; then
      start_opencode_server
    fi
  fi

  # Check for stop signal
  if [ -f "$STOP_FILE" ]; then
    echo ""
    echo -e "${YELLOW}${E_STOP} Stop signal detected. Stopping gracefully...${NC}"
    show_final_wall_time
    rm -f "$STOP_FILE"
    exit 2
  fi

  # Check if all stories complete
  ALL_COMPLETE=$(jq 'all(.userStories[]; .passes == true)' "$RALPH_JSON" 2>/dev/null || echo "false")
  if [ "$ALL_COMPLETE" = "true" ]; then
    # If --learn flag and all complete, run learn prompt
    if [[ "$LEARN_FLAG" == "true" ]]; then
      if [[ -f "$LEARNINGS_FILE" ]] && [[ -s "$LEARNINGS_FILE" ]]; then
        echo ""
        echo -e "${CYAN}${E_BOOK} All stories complete. Running learn prompt...${NC}"
        CODEBASE_PATTERNS=$(cat "$LEARNINGS_FILE")
        PROMPT=$(generate_learn_prompt "$LEARNINGS_FILE" "$CODEBASE_PATTERNS")

        # Debug: Write prompt to file for inspection
        if [[ -n "$DEBUG" ]]; then
          DEBUG_PROMPT_FILE="$RALPH_DIR/DEBUG-generated-prompt.md"
          {
            echo "# Debug: Learn Iteration Prompt"
            echo ""
            echo "## Environment Info"
            echo "- Current directory: $(pwd)"
            echo "- RALPH_DIR: $RALPH_DIR"
            echo "- LEARNINGS_FILE: $LEARNINGS_FILE"
            echo ""
            echo "---"
            echo ""
            echo "$PROMPT"
          } > "$DEBUG_PROMPT_FILE"
          echo -e "${DIM}Debug: Prompt written to $DEBUG_PROMPT_FILE${NC}"
        fi

        # Record start time
        LEARN_START=$(date +%s)
        
        # Create temp file for output capture
        TEMP_OUTPUT=$(mktemp)
        
        [[ -n "$DEBUG" ]] && echo "[DEBUG] Working directory: $(pwd)"

        # Run the tool with learn prompt (redirect output to file)
        if [[ "$TOOL" == "amp" ]]; then
          echo "$PROMPT" | "$TOOL_CMD" --dangerously-allow-all "${TOOL_ARGS[@]}" > "$TEMP_OUTPUT" 2>&1 &
          TOOL_PID=$!
        elif [[ "$TOOL" == "claude" ]]; then
          echo "$PROMPT" | "$TOOL_CMD" --dangerously-skip-permissions --print "${TOOL_ARGS[@]}" > "$TEMP_OUTPUT" 2>&1 &
          TOOL_PID=$!
        else
          # OpenCode: use run command with --attach to connect to server
          if ((${#TOOL_ARGS[@]})); then
            "$TOOL_CMD" run --attach "$OPENCODE_URL" "$PROMPT" "${TOOL_ARGS[@]}" > "$TEMP_OUTPUT" 2>&1 &
          else
            "$TOOL_CMD" run --attach "$OPENCODE_URL" "$PROMPT" > "$TEMP_OUTPUT" 2>&1 &
          fi
          TOOL_PID=$!
        fi
        
        # Stream output file to terminal using tail -f
        tail -f "$TEMP_OUTPUT" 2>/dev/null &
        TAIL_PID=$!

        # Start monitoring in background
        monitor_process "$TOOL_PID" "$LEARN_START" "$OPENCODE_PORT" &
        MONITOR_PID=$!
        
        # Wait for tool to complete
        wait "$TOOL_PID" || true
        
        # Stop tail and monitoring
        kill "$TAIL_PID" 2>/dev/null || true
        wait "$TAIL_PID" 2>/dev/null || true
        kill "$MONITOR_PID" 2>/dev/null || true
        wait "$MONITOR_PID" 2>/dev/null || true

        # Cleanup temp file
        rm -f "$TEMP_OUTPUT"

        echo ""
        echo -e "${GREEN}${E_SPARKLE} Learnings absorbed!${NC}"
      fi
    fi
    echo ""
    echo -e "${GREEN}${E_PARTY} Ralph already completed! All stories pass.${NC}"
    show_final_wall_time
    exit 0
  fi

  # Pre-compute all variables for this iteration
  precompute_variables
  
  # Ensure learnings file exists
  ensure_learnings_file

  echo ""
  echo -e "${BLUE}╔═════════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${NC} ${E_LOOP} ${BOLD}Ralph Iteration $i of $MAX_ITERATIONS${NC} ${DIM}($TOOL)${NC}"
  echo -e "${BLUE}║${NC} ${E_FOLDER} ${DIM}Project:${NC} $RALPH_DIR"
  if [[ "$WORKTREE_FLAG" == true ]]; then
    echo -e "${BLUE}║${NC} ${E_FOLDER} ${DIM}Worktree:${NC} $WORKTREE_DIR_RELATIVE"
  fi
  echo -e "${BLUE}║${NC} ${E_MEMO} ${DIM}Story:${NC}   $STORY_ID - $STORY_TITLE"
  echo -e "${BLUE}╚═════════════════════════════════════════════════════════════════════════════╝${NC}"

  # Generate the prompt - priority: --custom-prompt > .agents/ralph.md > embedded default
  if [[ -n "$CUSTOM_PROMPT" ]]; then
    PROMPT=$(sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
                 -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
                 -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g" \
                 -e "s|\\\$LEARNINGS_FILE|$LEARNINGS_FILE|g" \
                 -e "s|\\\$PRIMARY_PLAN_PATH|$PRIMARY_PLAN_PATH|g" \
                 -e "s|\\\$STORY_PLAN_PATH|${STORY_PLAN_PATH:---none--}|g" \
                 -e "s|\\\$BRANCH_NAME|$BRANCH_NAME|g" \
                 -e "s|\\\$STORY_ID|$STORY_ID|g" \
                 -e "s|\\\$STORY_TITLE|$STORY_TITLE|g" \
                 "$CUSTOM_PROMPT")
  elif [[ -f "$RALPH_DIR/.agents/ralph.md" ]]; then
     PROMPT=$(sed -e "s|\\\$RALPH_DIR|$RALPH_DIR|g" \
                 -e "s|\\\$RALPH_JSON|$RALPH_JSON|g" \
                 -e "s|\\\$PROGRESS_FILE|$PROGRESS_FILE|g" \
                 -e "s|\\\$LEARNINGS_FILE|$LEARNINGS_FILE|g" \
                 -e "s|\\\$PRIMARY_PLAN_PATH|$PRIMARY_PLAN_PATH|g" \
                 -e "s|\\\$STORY_PLAN_PATH|${STORY_PLAN_PATH:---none--}|g" \
                 -e "s|\\\$BRANCH_NAME|$BRANCH_NAME|g" \
                 -e "s|\\\$STORY_ID|$STORY_ID|g" \
                 -e "s|\\\$STORY_TITLE|$STORY_TITLE|g" \
                 "$RALPH_DIR/.agents/ralph.md")
  else
    PROMPT=$(generate_prompt "$TOOL" \
      "$STORY_ID" \
      "$STORY_TITLE" \
      "$STORY_DESCRIPTION" \
      "$STORY_CRITERIA" \
      "$PRIMARY_PLAN_PATH" \
      "$STORY_PLAN_PATH" \
      "$LEARNINGS_FILE_EXISTS" \
      "$BRANCH_NAME" \
      "$UPDATE_STORY_CMD" \
      "$RALPH_DIR" \
      "$RALPH_JSON" \
      "$PROGRESS_FILE" \
      "$LEARNINGS_FILE" \
      "$IS_LAST_STORY" \
      "$LEARN_FLAG")
  fi

  if [[ -n "$DEBUG" ]]; then
    # Debug: Write prompt to file for inspection
    DEBUG_PROMPT_FILE="$RALPH_DIR/DEBUG-generated-prompt.md"
    {
      echo "# Debug: Generated Prompt for Iteration $i"
      echo ""
      echo "## Environment Info"
      echo "- Current directory: $(pwd)"
      echo "- RALPH_DIR: $RALPH_DIR"
      echo "- RALPH_JSON: $RALPH_JSON"
      echo "- WORKTREE_FLAG: $WORKTREE_FLAG"
      echo "- WORKTREE_DIR: ${WORKTREE_DIR:-N/A}"
      echo "- WORKTREE_DIR_RELATIVE: ${WORKTREE_DIR_RELATIVE:-N/A}"
      echo ""
      echo "---"
      echo ""
      echo "$PROMPT"
    } > "$DEBUG_PROMPT_FILE"
    echo -e "${DIM}Debug: Prompt written to $DEBUG_PROMPT_FILE${NC}"
  fi

  # Record start time for failure detection
  ITERATION_START=$(date +%s)

  # Create temp file for output capture
  TEMP_OUTPUT=$(mktemp)

  [[ -n "$DEBUG" ]] && echo "[DEBUG] Working directory: $(pwd)"

  # Run the selected tool with the ralph prompt (redirect output to file)
  if [[ "$TOOL" == "amp" ]]; then
    echo "$PROMPT" | "$TOOL_CMD" --dangerously-allow-all "${TOOL_ARGS[@]}" > "$TEMP_OUTPUT" 2>&1 &
    TOOL_PID=$!
  elif [[ "$TOOL" == "claude" ]]; then
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    echo "$PROMPT" | "$TOOL_CMD" --dangerously-skip-permissions --print "${TOOL_ARGS[@]}" > "$TEMP_OUTPUT" 2>&1 &
    TOOL_PID=$!
  else
    # OpenCode: use run command with --attach to connect to server
    if ((${#TOOL_ARGS[@]})); then
      "$TOOL_CMD" run --attach "$OPENCODE_URL" "$PROMPT" "${TOOL_ARGS[@]}" > "$TEMP_OUTPUT" 2>&1 &
    else
      "$TOOL_CMD" run --attach "$OPENCODE_URL" "$PROMPT" > "$TEMP_OUTPUT" 2>&1 &
    fi
    TOOL_PID=$!
  fi

  # Stream output file to terminal using tail -f
  tail -f "$TEMP_OUTPUT" 2>/dev/null &
  TAIL_PID=$!

  # Start monitoring in background
  monitor_process "$TOOL_PID" "$ITERATION_START" "$OPENCODE_PORT" &
  MONITOR_PID=$!

  # Wait for tool to complete
  wait "$TOOL_PID" || true

  # Stop tail and monitoring
  kill "$TAIL_PID" 2>/dev/null || true
  wait "$TAIL_PID" 2>/dev/null || true
  kill "$MONITOR_PID" 2>/dev/null || true
  wait "$MONITOR_PID" 2>/dev/null || true

  # Calculate iteration duration
  ITERATION_END=$(date +%s)
  ITERATION_DURATION=$((ITERATION_END - ITERATION_START))

  # Check for completion signal
  if grep -q "<promise>COMPLETE</promise>" "$TEMP_OUTPUT"; then
    rm -f "$TEMP_OUTPUT"
    echo ""
    echo -e "${GREEN}${E_FINISH} Ralph completed all tasks!${NC}"
    echo -e "${DIM}Completed at iteration $i of $MAX_ITERATIONS${NC}"
    show_final_wall_time
    echo ""
    echo -e "${DIM}Working files have been cleaned up in a separate commit.${NC}"
    echo -e "${DIM}To undo cleanup: git revert HEAD${NC}"
    echo -e "${DIM}To recover files: git checkout HEAD~1 -- $RALPH_DIR/${NC}"
    exit 0
  fi

  # Cleanup temp file
  rm -f "$TEMP_OUTPUT"

  # Detect rapid failures (tool exiting too quickly)
  if [ "$ITERATION_DURATION" -lt "$MIN_ITERATION_TIME" ]; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo ""
    echo -e "${YELLOW}${E_WARN}Warning: Iteration completed very quickly (${ITERATION_DURATION}s). This may indicate an error.${NC}"
    echo -e "${YELLOW}Consecutive quick failures: $CONSECUTIVE_FAILURES/$MAX_FAILURES${NC}"
    
    if [ "$CONSECUTIVE_FAILURES" -ge "$MAX_FAILURES" ]; then
      echo ""
      echo -e "${RED}${E_ERROR} Error: Too many consecutive quick failures ($MAX_FAILURES).${NC}"
      echo -e "${RED}This usually indicates a configuration problem (e.g., invalid model, missing permissions).${NC}"
      echo "Please check the error messages above and fix the issue before retrying."
      show_final_wall_time
      exit 1
    fi
    
    echo -e "${DIM}Sleeping 3 seconds before retry...${NC}"
    sleep 3
  else
    # Reset failure counter on successful iteration
    CONSECUTIVE_FAILURES=0
    TOTAL_ITERATION_TIME=$((TOTAL_ITERATION_TIME + ITERATION_DURATION))
    iteration_time_str=$(format_time $ITERATION_DURATION)
    total_time_str=$(format_time $TOTAL_ITERATION_TIME)
    echo -e "${GREEN}${E_CHECK} Iteration $i complete.${NC} Time: ${iteration_time_str} | Total: ${total_time_str}"
    sleep 2
  fi
done

echo ""
echo -e "${YELLOW}${E_CLOCK}Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks.${NC}"
echo "Check $PROGRESS_FILE for status."
show_final_wall_time
exit 1
