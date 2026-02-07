# Task: Add Power Function

## Description
Add a `power` function to the math utilities module that raises a base to an exponent.

## Background
The `src/math.ts` module has the core arithmetic functions (add, subtract, multiply, divide). Now we add utility math operations starting with exponentiation. There is a TODO comment indicating where to add the power function.

## Reference Documentation
**Required:**
- Summary: `planning/add-math-functions/summary.md`

## Technical Requirements
1. Add function `power(base: number, exponent: number): number` to `src/math.ts`
2. Function returns `Math.pow(base, exponent)` (or uses `**` operator)
3. Remove the `// TODO: Add power function` comment
4. Export the function

## Dependencies
- Step 1 tasks (multiply, divide) should be completed first, but no hard dependency.

## Implementation Approach
1. Open `src/math.ts`
2. Replace the `// TODO: Add power function` comment with the function implementation
3. Run `npm run typecheck` to verify

## Acceptance Criteria

1. **Power function exists**
   - Given `src/math.ts` is open
   - When looking for the power function
   - Then `power(base: number, exponent: number): number` is exported and returns the correct result

2. **TODO removed**
   - Given the power function is implemented
   - When searching for TODO comments
   - Then no `// TODO: Add power function` comment exists

3. **Typecheck passes**
   - Given all changes are saved
   - When running `npm run typecheck`
   - Then it exits with code 0

## Metadata
- **Complexity**: Trivial
- **Labels**: Math, Utility
- **Required Skills**: TypeScript basics
