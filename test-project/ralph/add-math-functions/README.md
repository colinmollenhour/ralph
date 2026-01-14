# Add Missing Math Functions

## Overview
Add the remaining math functions to complete the math utilities library.

## User Stories

### US-001: Add multiply function
**Description:** As a developer, I want a multiply function to multiply two numbers.

**Acceptance Criteria:**
- [ ] Add `multiply(a: number, b: number): number` function to src/math.ts
- [ ] Function returns the product of a and b
- [ ] Remove the TODO comment for multiply
- [ ] Typecheck passes

### US-002: Add divide function  
**Description:** As a developer, I want a divide function to divide two numbers.

**Acceptance Criteria:**
- [ ] Add `divide(a: number, b: number): number` function to src/math.ts
- [ ] Function returns a divided by b
- [ ] Throw error if b is zero
- [ ] Remove the TODO comment for divide
- [ ] Typecheck passes

### US-003: Add power function
**Description:** As a developer, I want a power function to calculate exponents.

**Acceptance Criteria:**
- [ ] Add `power(base: number, exponent: number): number` function to src/math.ts
- [ ] Function returns base raised to the exponent
- [ ] Remove the TODO comment for power
- [ ] Typecheck passes

### US-004: Add modulo function
**Description:** As a developer, I want a modulo function to get the remainder of division.

**Acceptance Criteria:**
- [ ] Add `modulo(a: number, b: number): number` function to src/math.ts
- [ ] Function returns the remainder of a divided by b
- [ ] Remove the TODO comment for modulo
- [ ] Typecheck passes

### US-005: Add absolute value function
**Description:** As a developer, I want an absolute value function to get the magnitude of a number.

**Acceptance Criteria:**
- [ ] Add `abs(n: number): number` function to src/math.ts
- [ ] Function returns the absolute value of n
- [ ] Remove the TODO comment for absolute value
- [ ] Typecheck passes

## Technical Notes
- Keep the same coding style as existing functions
- Use built-in Math functions where appropriate (Math.pow, Math.abs)
- Division by zero should throw an Error with a descriptive message
