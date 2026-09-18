---
name: repo-understanding
description: Understand a repository's structure, architecture, conventions, and existing implementations before making substantial changes. Use at the start of non-trivial tasks, in unfamiliar codebases, or before adding functionality in a new area.
---

# Repo Understanding

Understand before you code. Do not start implementing until you can answer the
points below concisely.

## 1. Map the structure
- Identify entry points, build files, configuration, and top-level layout.
- Note the primary languages, frameworks, and tooling.
- Locate tests, docs, and CI.

## 2. Learn the conventions
- Read contributor docs (`AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `docs/`).
- Match existing naming, formatting, error handling, and module patterns.
- Use the configured formatter instead of reformatting by hand.

## 3. Find existing implementations first
- Search for the behavior before writing new code.
- Reuse existing utilities, modules, types, and patterns.
- Extend existing mechanisms rather than building a parallel one.

## 4. Trace dependencies and ownership
- Follow imports and callers to see who owns what.
- Identify the source of truth for each concern (config, data, state).
- Note coupling and side effects before touching a shared component.

## 5. Keep the change scoped
- List the files that should change and the files that must not.
- Do not touch unrelated files, formatting, or dependencies.
- If an unrelated change is required, call it out explicitly.

## 6. Report, then act
Summarize relevant files, existing patterns, the planned change, and any
uncertainty. For substantial work use `/plan`. Then implement the smallest
change consistent with the codebase.

## Nix / declarative repositories
- The repository is the source of truth; never rely on imperative edits.
- Make changes through the existing modules/flake structure.
- Validate (`nix flake check`, `nixos-rebuild dry-build`) before claiming success.
