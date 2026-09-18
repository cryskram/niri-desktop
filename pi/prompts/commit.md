---
description: Prepare a conventional commit from current changes (never commits automatically)
argument-hint: "[scope or notes]"
---
# Commit

Notes: $ARGUMENTS

Do not commit or push. Prepare and propose a commit only.

1. **Inspect** — run `git status` and `git diff` (and `git diff --cached`). Read the actual changes; do not trust a summary.
2. **Understand** — state in one or two lines what changed and why.
3. **Separate concerns** — flag accidental, unrelated, generated, or debugging changes. Recommend splitting if the diff mixes concerns.
4. **Check for secrets** — scan the diff for credentials, tokens, API keys, private keys, `.env`/`.env.*`, `*.pem`, `*.key`, `.aws/`, `.ssh/`, and connection strings. If any appear, stop and warn; do not include them.
5. **Check consistency** — confirm changes match repo conventions and that generated files are intentional.
6. **Propose** — give one conventional commit message in the repo's style: `type(scope): summary`, with an optional body listing key changes. Match the types already used in `git log`.
7. **Wait** — present the message and ask before committing. Only commit/push if explicitly asked, and never force-push.
