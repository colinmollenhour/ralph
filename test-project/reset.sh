#!/usr/bin/env bash
# Reset test-project to a clean initial state for re-running Ralph tests
set -e

cd "$(dirname "$0")"

echo "Resetting test-project..."

# Remove git directory
rm -rf .git

# Remove worktrees if any
rm -rf .worktrees

# Reset src/math.ts to original state with TODOs
cat > src/math.ts << 'EOF'
// Simple math utilities

export function add(a: number, b: number): number {
  return a + b;
}

export function subtract(a: number, b: number): number {
  return a - b;
}

// TODO: Add multiply function
// TODO: Add divide function
// TODO: Add power function
// TODO: Add modulo function
// TODO: Add absolute value function
EOF

# Reset ralph.json with all stories as passes: false
cat > ralph/add-math-functions/ralph.json << 'EOF'
{
  "source": "ralph/add-math-functions/README.md",
  "project": "test-project",
  "branchName": "ralph/add-math-functions",
  "description": "Add Missing Math Functions",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add multiply function",
      "description": "As a developer, I want a multiply function to multiply two numbers.",
      "acceptanceCriteria": [
        "Add multiply(a: number, b: number): number function to src/math.ts",
        "Function returns the product of a and b",
        "Remove the TODO comment for multiply",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-002",
      "title": "Add divide function",
      "description": "As a developer, I want a divide function to divide two numbers.",
      "acceptanceCriteria": [
        "Add divide(a: number, b: number): number function to src/math.ts",
        "Function returns a divided by b",
        "Throw error if b is zero",
        "Remove the TODO comment for divide",
        "Typecheck passes"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-003",
      "title": "Add power function",
      "description": "As a developer, I want a power function to calculate exponents.",
      "acceptanceCriteria": [
        "Add power(base: number, exponent: number): number function to src/math.ts",
        "Function returns base raised to the exponent",
        "Remove the TODO comment for power",
        "Typecheck passes"
      ],
      "priority": 3,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-004",
      "title": "Add modulo function",
      "description": "As a developer, I want a modulo function to get the remainder of division.",
      "acceptanceCriteria": [
        "Add modulo(a: number, b: number): number function to src/math.ts",
        "Function returns the remainder of a divided by b",
        "Remove the TODO comment for modulo",
        "Typecheck passes"
      ],
      "priority": 4,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-005",
      "title": "Add absolute value function",
      "description": "As a developer, I want an absolute value function to get the magnitude of a number.",
      "acceptanceCriteria": [
        "Add abs(n: number): number function to src/math.ts",
        "Function returns the absolute value of n",
        "Remove the TODO comment for absolute value",
        "Typecheck passes"
      ],
      "priority": 5,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

# Reset progress.txt to empty header
cat > ralph/add-math-functions/progress.txt << 'EOF'
# Ralph Progress Log
Started: 2026-01-14 12:00
Source PRD: ralph/add-math-functions/README.md
---
EOF

# Reset AGENTS.md (learnings file)
cat > ralph/add-math-functions/AGENTS.md << 'EOF'
# Add Missing Math Functions - Learnings

EOF

# Reset .last-branch
echo "ralph/add-math-functions" > ralph/add-math-functions/.last-branch

# Reset .gitignore (remove .worktrees/ if present)
cat > .gitignore << 'EOF'
node_modules/
EOF

# Initialize fresh git repo
git init
git add .
git rm -rf --cached ralph
git commit -m "initial"

echo "Done! Test project reset to clean state."
