# Task: Add Absolute Value Function

## Description
Add an `abs` function to the math utilities module that returns the absolute (non-negative) value of a number.

## Background
The `src/math.ts` module has the core arithmetic, power, and modulo functions. The absolute value function is the final utility function to complete the module. There is a TODO comment indicating where to add it.

## Reference Documentation
**Required:**
- Summary: `planning/add-math-functions/summary.md`

## Technical Requirements
1. Add function `abs(n: number): number` to `src/math.ts`
2. Function returns `Math.abs(n)`
3. Remove the `// TODO: Add absolute value function` comment
4. Export the function

## Dependencies
- S02-T02 (modulo) should be completed first to maintain file ordering, but is not a hard dependency.

## Implementation Approach
1. Open `src/math.ts`
2. Replace the `// TODO: Add absolute value function` comment with the function implementation
3. Run `npm run typecheck` to verify

## Acceptance Criteria

1. **Abs function exists**
   - Given `src/math.ts` is open
   - When looking for the abs function
   - Then `abs(n: number): number` is exported and returns `Math.abs(n)`

2. **TODO removed**
   - Given the abs function is implemented
   - When searching for TODO comments
   - Then no `// TODO: Add absolute value function` comment exists

3. **Typecheck passes**
   - Given all changes are saved
   - When running `npm run typecheck`
   - Then it exits with code 0

## Metadata
- **Complexity**: Trivial
- **Labels**: Math, Utility
- **Required Skills**: TypeScript basics
