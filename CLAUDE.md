# Ralph Agent Instructions

You are an autonomous coding agent working on a software project managed by Ralph.

## Your Task

1. Read the task specification file provided in the prompt (a `.code-task.md` file)
2. Read any referenced design documents and research files as directed by the task spec
3. If a `memory.md` file is listed in context, read it for learnings from previous iterations
4. Implement the task meeting all acceptance criteria
5. Run quality checks (typecheck, lint, test - whatever the project requires)
6. Update ralph.json to mark the task as complete using the provided `jq` command
7. Append progress to `progress.md`
8. Record learnings to `memory.md` if you discover reusable patterns
9. Commit ALL changes with message: `feat: [Task ID] - [Task Title]`

**CRITICAL: Use the exact `jq | sponge` command from the prompt to update ralph.json. Do NOT edit ralph.json with your editor — other tasks have already been marked complete and editing the file directly will overwrite their status.**

## Progress Report Format

APPEND to progress.md (never replace, always append):
```
### [Date/Time] - [Task ID]
Implemented: [1-2 sentence summary]
Files changed:
- path/to/file (created/modified/deleted)
---
```

## Learnings Storage

If you discover a **reusable pattern** that future iterations should know, append it to `memory.md`:

```
- Use Drizzle ORM for all database operations - import from src/db/schema.ts
- Auth middleware lives in src/middleware/auth.ts
- Always run typecheck before committing: npm run typecheck
```

Only add patterns that are **general and reusable**, not task-specific details.

## Quality Requirements

- ALL commits must pass your project's quality checks (typecheck, lint, test)
- Do NOT commit broken code
- Keep changes focused and minimal
- Follow existing code patterns

## Stop Condition

After completing a task, check if ALL tasks have `passes: true` in ralph.json.

If ALL tasks are complete and passing, reply with:
<promise>COMPLETE</promise>

If there are still tasks with `passes: false`, end your response normally (another iteration will pick up the next task).

## Important

- Work on ONE task per iteration
- Commit frequently
- Keep CI green
- Read memory.md before starting for learnings from previous iterations
