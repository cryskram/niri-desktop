# Shared Pi Brain

This is the source map for Vageesh's declarative Pi guidance. It is intentionally Pi-only for now: Pi sessions and delegated Pi agents use the same files; OpenCode, Claude Code, and other products are not wired to it.

## What loads where

| Source | Purpose | How Pi receives it |
|---|---|---|
| `pi/brain/AGENTS.md` | Global working contract across projects | Linked to `~/.pi/agent/AGENTS.md` by Home Manager; Pi treats it as user-level context |
| `pi/brain/` | Readable copy of this source map and related files | Linked to `~/.pi/agent/brain/` so any Pi child can find the same canonical guidance |
| `pi/brain/APPEND_SYSTEM.md` | Short, always-on Pi instructions and memory bootstrap | Passed via `programs.pi.coding-agent.rules` as `--append-system-prompt` |
| Repository-root `AGENTS.md` | niri-desktop-specific operating manual | Pi discovers it when working in this repository |
| `pi/context.md` | Compact runnable context for niri-desktop | Read for work in this repo; linked from root `context.md` |
| `pi/skills/learnings/` | Shared durable preferences, decisions, and gotchas | `SKILL.md` defines the read/write protocol; `LEARNINGS.md` is the journal |
| `pi/skills/vageesh/` | Future personal decision-style skill | Scaffold only; use only when explicitly relevant, and do not invent missing profile data |

Pi's built-in `SYSTEM.md` **replaces** its default system prompt, so this setup deliberately does not use it. Built-in Pi subagents are explicitly configured in `modules/core.nix` to inherit project context, global context, and skills; they otherwise omit some of this shared brain by default. `APPEND_SYSTEM.md` is not a second journal: stable instructions belong in the guidance files, and dated observations belong in `LEARNINGS.md`.

## Authority and change rules

1. System/developer safety constraints and the current user's instructions remain controlling.
2. Global `AGENTS.md` defines the cross-project default; a repository's own `AGENTS.md` adds local architecture and procedures. Follow all applicable instructions and surface genuine conflicts instead of silently choosing.
3. Skills add task-specific procedures. Office/domain skills remain authoritative for their domains.
4. `LEARNINGS.md` is evidence of preferences and past decisions, not a command to ignore a new request. Preserve its history and distinguish confirmed facts from tentative inferences.

At the start of Pi work, use the `learnings` skill to read its instructions and the full journal. For niri-desktop work, also read repository-root `AGENTS.md` and `pi/context.md`; for other repositories, inspect their applicable instructions before editing. Delegated agents should receive enough task context to follow the same files; do not create agent-specific shadow journals.

## Where to edit

- Cross-project working principles: `pi/brain/AGENTS.md`.
- Compact always-on Pi bootstrap and non-negotiables: `pi/brain/APPEND_SYSTEM.md`.
- niri-desktop-specific architecture: repository-root `AGENTS.md` and `pi/context.md`.
- Confirmed durable preferences and reusable discoveries: `pi/skills/learnings/LEARNINGS.md`.
- Confirmed personal decision-style profile (when Vageesh supplies it): `pi/skills/vageesh/PROFILE.md`.

All changes to this brain are made in this repository and flow through the declarative Nix configuration. Do not edit generated copies under `~/.pi` by hand.
