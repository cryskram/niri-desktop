---
name: learnings
description: Durable journal for Vageesh's preferences, project decisions, and reusable gotchas. Use at session start, before any preference-sensitive decision, and whenever a correction, preference, or non-obvious discovery occurs that should survive this session.
---

# Learnings — Journal Skill

One journal, many sessions. This skill owns `LEARNINGS.md` in this same directory. You read it to recall, you append to it to remember. It is the single source of truth for "how Vageesh wants things done" + "what this repo has already learned."

## When to use

- **Session start** (mandatory): Read `LEARNINGS.md` before planning, answering, or touching code. If the task touches preferences, tooling, Nix, Niri/Noctalia, or any prior decision, restore that context first.
- **Before any preference-sensitive action**: Naming, structure, formatting, commit style, Nix patterns, shell (fish), theme — check learnings before assuming.
- **When the user corrects you, states a preference, or says "remember this"**: Append immediately.
- **After you discover something reusable**: A pitfall, a non-obvious command, a module pattern that works (or doesn't), a quirk of Niri/Noctalia/pi.nix — distill it and append.
- **End of session / before handoff**: If anything new was learned, append before closing.

Do not treat this as optional. `pi/rules.md` requires it. If unsure whether something is worth remembering, remember it — 2-4 lines is cheap, re-learning is expensive.

## The file

`pi/skills/learnings/LEARNINGS.md` — append-only, reverse chronological (newest on top). Every entry follows the template. No walls of text. Aim for 2-4 lines of signal, not 20 lines of narration.

### Entry template

```markdown
## YYYY-MM-DD — Title (Category) — `scope/tag`

- What: one sentence. The preference, decision, or gotcha.
- Why/Context: one sentence. When it applies, what it replaces.
- How/Apply: one command, path, or rule to follow next time.

Source: session summary / user correction / observed failure — one line.
```

Categories: `preference` · `workflow` · `nix` · `niri/noctalia` · `pi` · `tooling` · `decision` · `gotcha`

Tags: short scopes like `nix/flake`, `pi/skill`, `git/commit`, `shell/fish`, `dev/devenv`.

### Size guidance

- Entry: 2-6 lines (not counting header/source). No stack traces, no full code dumps — link the file:line or commit instead.
- Section: no max overall file size, but compact — if `LEARNINGS.md` grows past ~300 lines, propose a compaction (archive old year into `LEARNINGS.YYYY.md` and keep active preferences at top).

## Read protocol

1. `read` this `SKILL.md` (you are here).
2. `read` `LEARNINGS.md` in full (it is small by design).
3. Keep preferences in working memory for the rest of the session. Cite them when you act on them ("per learnings 2026-10-07 — fish abbrs").

## Write protocol

1. Ensure `LEARNINGS.md` still reads coherently — check last entry's date/title to avoid duplicates.
2. Use `edit` to append ONE entry at the top (just under the header), preserving reverse chronological order. Never rewrite history, only append.
3. Keep edits atomic and precise — one `edit` with `oldText` = header block → new entry inserted. Do not reformat the whole file.
4. If the learning corrects a prior entry, add a new entry that says `Supersedes: YYYY-MM-DD — Title` and keep both. Single source of truth means history is visible.

### Examples (style reference — do not duplicate literally)

```markdown
## 2026-10-07 — Prefer fish abbrs over aliases (preference) — `shell/fish`

- What: Use `abbrs` for interactive shortcuts (`g`→`git`, `gs`→`git status -sb`); reserve `aliases` for non-interactive compatibility.
- Why: Abbrs expand visibly and compose with fish completions; aliases hide intent.
- How: Edit `home/shell.nix` `programs.fish.shellAbbrs`.

Source: user correction in niri-desktop session — requested abbr-first shell.
```

```markdown
## 2026-10-06 — Never `nix flake update` all inputs at once (gotcha) — `nix/flake`

- What: Update one input at a time and dry-run build cost; `noctalia` always rebuilds from source (~15min), `nixpkgs` may rebuild kernel modules.
- Why: Blind mass update burned an hour; cost matrix is in README § Updating inputs.
- How: `nix flake update <input> && nix build --dry-run --no-link '.#nixosConfigurations."nixos".config.system.build.toplevel' | grep drv`

Source: learned from README + failed switch.
```

## Rules

- The repo is the source of truth. All learnings persist as files in `pi/skills/learnings/` and are committed via `nixos-rebuild dry-build` validated changes — never imperative `~/.pi` edits.
- Keep office skills (`Projects/TAP/...` via `extraArgs` in `modules/core.nix`) authoritative for domain work; learnings complement, not override, them.
- Never commit secrets. If a learning touches a secret boundary, describe the pattern, not the value.
- This file (`SKILL.md`) is instructions — do not put journal entries here. Journal lives in `LEARNINGS.md`.
