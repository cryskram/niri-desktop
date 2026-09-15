# Review — Backend Coding Practices

Review per `backend-coding-practices` (Controller→Service→Repository, `hasAuthority('PERMISSION')`, cache `service:entity:id` TTL, soft-delete `deleted_at`, `created_at`/`updated_at`, transactions `WithTx`/`@Transactional`, PII mask `user***@`, `X-Correlation-ID`, RBAC not role, DRY/early-return, pagination max 100).

For each file:
- **Flag** — violations, missing guards, raw errors escaping, hard deletes, string enums.
- **Suggest** — minimal fix with file:line.
- **Security** — secrets, permission strings `RESOURCE_ACTION`, headers.
- **Tests** — `Test<Service>_<Scenario>` coverage.

Be concise, actionable, Mocha-style.
