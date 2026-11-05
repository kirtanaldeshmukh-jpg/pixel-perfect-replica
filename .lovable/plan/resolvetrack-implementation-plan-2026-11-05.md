# ResolveTrack implementation plan

## Goal
Replace the blank home page with a usable, secure grievance-management application backed by Lovable Cloud. Preserve the current TanStack Start stack rather than introducing the brief's unsupported Java/Spring Boot and React Router stack.

## Build
- Create the institutional design system and responsive ResolveTrack workspace with login/registration, student dashboard, complaint submission/tracking, campus issue list, and role-aware administration views.
- Enable email/password and managed Google/Lovable sign-in; create student profiles automatically and keep privileged roles in a protected roles table. Students cannot self-assign staff or administrator access.
- Add Cloud tables and row-level policies for profiles, departments, roles, complaints, support, assignment/status history, notifications, feedback, and escalations.
- Implement persisted complaints, category-to-department recommendations, explainable priority scoring, token-based duplicate suggestions, support counts, status timelines, and database-driven dashboard/analytics.
- Provide secure admin/staff controls only to users whose roles are assigned, plus setup notes for role provisioning and local development.
- Run the existing tests and verify the main signed-out/sign-up and public dashboard experience; verify authenticated workflows only when an available session allows it.

## Technical details
- Use the generated Cloud client and TanStack Start conventions, with database access protected by RLS and authenticated server functions where privileged checks are needed.
- Overdue state will be derived from persisted deadlines and active status; no frequent polling schedule or paid AI service will be added.
- The brief requests demo staff/admin credentials, but those will not be fabricated or seeded insecurely. Student registration is self-service; staff/admin roles remain controlled.
- The requested Java REST server, deployment to Vercel/Render, and institution-specific demo accounts cannot be delivered by this TanStack project in the same implementation. Keep the app runnable in the existing workspace and document these limitations.
