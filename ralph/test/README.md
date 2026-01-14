# Test Feature - Authentication System

## Overview
This is a test fixture for validating Ralph's token-efficient context loading.

## Architecture
- Database: PostgreSQL with Drizzle ORM  
- Auth: JWT tokens in httpOnly cookies
- Frontend: React with Nuxt UI components

## User Stories Overview
This feature has 3 user stories split across database and UI domains:
- US-001: Database schema (database.md)
- US-002: Login form UI (ui-components.md)
- US-003: Simple fix (no domain file)

## Success Criteria
- All stories completable in one iteration
- Token-efficient context loading validated
