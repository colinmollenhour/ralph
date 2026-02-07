# Task: Add Divide Function

## Description
Add a `divide` function to the math utilities module that returns the quotient of two numbers, with a guard against division by zero.

## Background
The `src/math.ts` module currently exports `add()` and `subtract()` (and `multiply()` after S01-T01). There is a TODO comment indicating where to add the divide function. Unlike multiply, divide has an edge case: division by zero must throw an error.

## Reference Documentation
**Required:**
- Summary: `planning/add-math-functions/summary.md`

## Technical Requirements
1. Add function `divide(a: number, b: number): number` to `src/math.ts`
2. Function returns `a / b`
3. If `b` is zero, throw an `Error` with message `"Division by zero"`
4. Remove the `// TODO: Add divide function` comment
5. Export the function

## Dependencies
- S01-T01 (multiply) should be completed first to maintain file ordering, but is not a hard dependency.

## Implementation Approach
1. Open `src/math.ts`
2. Replace the `// TODO: Add divide function` comment with the function implementation
3. Include the zero-division guard as the first line of the function body
4. Run `npm run typecheck` to verify

## Acceptance Criteria

1. **Divide function exists**
   - Given `src/math.ts` is open
   - When looking for the divide function
   - Then `divide(a: number, b: number): number` is exported and returns `a / b`

2. **Zero-division guard**
   - Given the divide function is called with `b = 0`
   - When the function executes
   - Then it throws an `Error` with message `"Division by zero"`

3. **TODO removed**
   - Given the divide function is implemented
   - When searching for TODO comments
   - Then no `// TODO: Add divide function` comment exists

4. **Typecheck passes**
   - Given all changes are saved
   - When running `npm run typecheck`
   - Then it exits with code 0

## Metadata
- **Complexity**: Trivial
- **Labels**: Math, Core Arithmetic, Error Handling
- **Required Skills**: TypeScript basics
