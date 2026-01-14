# Test Project for Ralph

This is a minimal test project for trying out Ralph.

## Quick Test

From this directory, run:

```bash
# See what Ralph will do (without running the agent)
../ralph.sh ralph/add-math-functions --next-prompt

# Run Ralph with 2 iterations max
../ralph.sh ralph/add-math-functions -n 2

# Or with a specific tool
../ralph.sh ralph/add-math-functions -n 2 --tool opencode
```

## What Ralph Will Do

1. Add a `multiply` function to `src/math.ts`
2. Add a `divide` function to `src/math.ts`
3. Remove the TODO comments
4. Run typecheck to verify

## Files

- `src/math.ts` - The file Ralph will modify
- `ralph/add-math-functions/` - Ralph execution directory
- `plans/add-math-functions.md` - Source PRD
