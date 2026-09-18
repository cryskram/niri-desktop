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
- **Consistency & complexity** — match existing codebase patterns; flag unnecessary abstraction, dead code, and missing tests.
- **Style** — readability, comments where needed, minimal diff.

Prioritize real issues (correctness, security, data, concurrency) over stylistic nitpicks. For each issue: **Flag** (what/why) → **Suggest** (minimal fix file:line). Be concise, actionable.
