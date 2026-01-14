# Test Feature - Authentication System - Learnings

- Use Drizzle ORM for all database operations - import from src/db/schema.ts
- Auth middleware lives in src/middleware/auth.ts
- Always run typecheck before committing: npm run typecheck
- JWT secret must be in .env as JWT_SECRET (32+ chars minimum)
- Nuxt UI components auto-imported from #components
