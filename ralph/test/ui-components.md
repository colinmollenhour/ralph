# Authentication - UI Components Domain

## Login Form Component
- Email input (validated for format)
- Password input (obscured)
- Submit button (disabled while loading)
- Error messages shown inline

## Design System
- Use Nuxt UI FormGroup and UInput components
- Form validation with zod schema
- Error display with UAlert component
- Mobile-first responsive (test at 375px)

## API Integration
- POST to /api/auth/login
- Handle loading states
- Display server errors to user
