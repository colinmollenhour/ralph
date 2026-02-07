# Task: Add Modulo Function

## Description
Add a `modulo` function to the math utilities module that returns the remainder of integer division.

## Background
The `src/math.ts` module has the core arithmetic and power functions. The modulo function provides the remainder operation. There is a TODO comment indicating where to add it.

## Reference Documentation
**Required:**
- Summary: `planning/add-math-functions/summary.md`

## Technical Requirements
1. Add function `modulo(a: number, b: number): number` to `src/math.ts`
2. Function returns `a % b`
3. Remove the `// TODO: Add modulo function` comment
4. Export the function

## Dependencies
- S02-T01 (power) should be completed first to maintain file ordering, but is not a hard dependency.

## Implementation Approach
1. Open `src/math.ts`
2. Replace the `// TODO: Add modulo function` comment with the function implementation
3. Run `npm run typecheck` to verify

## Acceptance Criteria

1. **Modulo function exists**
   - Given `src/math.ts` is open
   - When looking for the modulo function
   - Then `modulo(a: number, b: number): number` is exported and returns `a % b`

2. **TODO removed**
   - Given the modulo function is implemented
   - When searching for TODO comments
   - Then no `// TODO: Add modulo function` comment exists

3. **Typecheck passes**
   - Given all changes are saved
   - When running `npm run typecheck`
   - Then it exits with code 0

## Metadata
- **Complexity**: Trivial
- **Labels**: Math, Utility
- **Required Skills**: TypeScript basics
