# Task: Add Multiply Function

## Description
Add a `multiply` function to the math utilities module that returns the product of two numbers.

## Background
The `src/math.ts` module currently exports `add()` and `subtract()`. There is a TODO comment indicating where to add the multiply function. This is a straightforward arithmetic operation with no edge cases.

## Reference Documentation
**Required:**
- Summary: `planning/add-math-functions/summary.md`

## Technical Requirements
1. Add function `multiply(a: number, b: number): number` to `src/math.ts`
2. Function returns `a * b`
3. Remove the `// TODO: Add multiply function` comment
4. Export the function

## Dependencies
- None. This is a standalone function.

## Implementation Approach
1. Open `src/math.ts`
2. Replace the `// TODO: Add multiply function` comment with the function implementation
3. Run `npm run typecheck` to verify

## Acceptance Criteria

1. **Multiply function exists**
   - Given `src/math.ts` is open
   - When looking for the multiply function
   - Then `multiply(a: number, b: number): number` is exported and returns `a * b`

2. **TODO removed**
   - Given the multiply function is implemented
   - When searching for TODO comments
   - Then no `// TODO: Add multiply function` comment exists

3. **Typecheck passes**
   - Given all changes are saved
   - When running `npm run typecheck`
   - Then it exits with code 0

## Metadata
- **Complexity**: Trivial
- **Labels**: Math, Core Arithmetic
- **Required Skills**: TypeScript basics
