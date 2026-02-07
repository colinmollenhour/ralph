# Test Project for Ralph

This is a minimal test project for trying out Ralph.

## Quick Test

From this directory, run:

```bash
# Reset to clean state first
bash reset.sh

# See what Ralph will do (without running the agent)
../ralph.sh planning/add-math-functions --next-prompt

# Check task status
../ralph.sh planning/add-math-functions --status

# Run Ralph with 5 iterations max
../ralph.sh planning/add-math-functions -n 5

# Or with a specific tool
../ralph.sh planning/add-math-functions -n 5 --tool claude
```

## What Ralph Will Do

1. Add a `multiply` function to `src/math.ts`
2. Add a `divide` function with zero-division guard
3. Add a `power` function
4. Add a `modulo` function
5. Add an `abs` function
6. Remove all TODO comments
7. Pass typecheck after each task

## Files

- `src/math.ts` - The file Ralph will modify
- `planning/add-math-functions/` - Planning directory (SOP format)
  - `summary.md` - Project overview
  - `implementation/ralph.json` - Task tracker
  - `implementation/plan.md` - Step checklist
  - `implementation/step01/` - Core arithmetic tasks (multiply, divide)
  - `implementation/step02/` - Utility math tasks (power, modulo, abs)
- `reset.sh` - Reset everything to clean state
