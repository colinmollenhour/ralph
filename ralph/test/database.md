# Authentication - Database Domain

## Schema Requirements
- Users table: id, email (unique), passwordHash, createdAt, updatedAt
- Use bcrypt for password hashing (cost factor 12)
- Email must be lowercase normalized

## Migration Strategy
- Create with: `drizzle-kit generate`
- Apply with: `drizzle-kit migrate`
- Seed test user: admin@test.com / password123

## Technical Notes
- Use Drizzle ORM text() for email, not varchar()
- createdAt uses timestamp().defaultNow()
- Email uniqueness enforced at DB level with .unique()
