---
description: General code review — correctness, design, security, tests
argument-hint: "<files>"
---
# Review — General Code Review

Target: $ARGUMENTS

Act as a senior reviewer for the target above. For each file/change:

- **Correctness** — bugs, edge cases, error handling, null/empty, off-by-one.
- **Design** — naming, separation, DRY, early returns, complexity.
- **Security** — authZ/authN, input validation, secrets, injection, PII.
- **Performance** — N+1, pagination, caching, allocations, async.
- **Tests** — coverage, happy + negative + edge, naming `Test<Feature>_<Scenario>`.
- **Style** — readability, comments where needed, minimal diff.

For each issue: **Flag** (what/why) → **Suggest** (minimal fix file:line). Be concise, actionable.
