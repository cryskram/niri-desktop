---
description: Debug systematically — reproduce, gather evidence, test hypotheses, fix the root cause
argument-hint: "<problem>"
---
# Debug

Problem: $ARGUMENTS

Work through these steps in order. Do not change code speculatively.

1. **Understand** — restate expected vs actual behavior in one or two lines.
2. **Reproduce** — find the smallest reliable reproduction (command, test, input). If it cannot be reproduced, say so and state what evidence is missing.
3. **Gather evidence** — read the relevant code, logs, config, and runtime output. Cite exact files/lines and observed values. Use `git log`/`git blame` for recent changes.
4. **Hypotheses** — list 2–4 concrete, falsifiable hypotheses, most likely first.
5. **Test** — verify each hypothesis with a targeted check. Report what confirmed or ruled it out.
6. **Fix** — address the root cause, not the symptom. Keep the change minimal.
7. **Verify** — rerun the reproduction and the relevant tests. Show the result.

If the evidence points somewhere unexpected, say so instead of forcing a fix.
