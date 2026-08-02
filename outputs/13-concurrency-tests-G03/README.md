# Concurrency Tests — Group 03

Status: scaffold created; executable scripts depend on artifact 12.

Planned files:

- `00-setup.sql`
- `01-unsafe-session-a.sql`
- `02-unsafe-session-b.sql`
- `03-unsafe-verify.sql`
- `04-safe-session-a.sql`
- `05-safe-session-b.sql`
- `06-safe-verify.sql`
- `07-boundary-and-regression-tests.sql`
- `99-cleanup.sql`

Each two-session test will state the required execution order and expected result. Captured results must include proof that the unsafe workflow can violate the invariant and that the safe workflow prevents two overlapping approved commits.
