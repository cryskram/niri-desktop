# Learnings — Journal for niri-desktop + Pi

Reverse chronological. Newest on top. Each entry is 2-4 lines of durable signal. See `SKILL.md` for the entry template and when to read/write.

---

## 2026-10-07 — This journal is the preference memory (decision) — `pi/skill`

- What: `pi/skills/learnings/LEARNINGS.md` is the single append-only journal for preferences, decisions, and reusable gotchas across all pi agents/sessions.
- Why: Agent memory resets per session; without this file preferences re-learn every time. Rules enforce read-at-start, write-on-learn.
- How: At session start `read` this file; on any new signal `edit` an entry on top. Keep entries 2-4 lines, tagged `category` + `scope/tag`.

Source: bootstrapped with niri-desktop declarative setup — repo is source of truth for pi config.

## 2026-10-07 — Declarative repo is law (decision) — `nix/core`

- What: All system, pi, and HM config lives in `~/niri-desktop` flake (`flake.nix`, `modules/`, `home/`, `pi/`). Never imperatively edit `~/.pi` or running system; change repo → `nix flake check` → `nixos-rebuild dry-build`.
- Why: Rebuilds must reproduce on fresh checkout; imperative drift breaks that.
- How: `pi` is `programs.pi.coding-agent` via `pi.nix` (see `modules/core.nix`); `pi/packages.nix` pins extensions; `AGENTS.md` §2/§9 is the rule.

Source: `AGENTS.md` + `modules/core.nix` + `README.md` Quick start.

## 2026-10-07 — Office skills are external and authoritative (preference) — `pi/skill`

- What: Company skills under `~/Projects/TAP/claude-plugins/...` (backend-coding-practices, backend-to-qa, web-to-qa, mobile-to-qa, generate-test-cases, qa-signoff, schema-reference, query-patterns) are wired via `extraArgs --skill` and stay outside the repo.
- Why: Keep TAP domain authoritative; repo-owned skills are only `repo-understanding` and `learnings`.
- How: Do not move or duplicate TAP skills into `pi/skills/`; `modules/core.nix` `extraArgs` is the interface.

Source: `modules/core.nix` + `.gitignore` + user instruction "retain my office skills".

## 2026-10-07 — Prompts removed in favour of skills (decision) — `pi/prompt`

- What: `pi/prompts/*.md` removed — skills preferred for workflows needing context; prompt templates are thin `/` commands, not skill replacements (see pi docs).
- Why: Skills carry description + on-demand loading; prompts add noise without specialization.
- How: `promptTemplates = [ ../pi/prompts ]` removed from `modules/core.nix`; `pi/prompts/` left empty with `.gitkeep` for future intentional templates.

Source: user decision — "remove any existing prompts" — validated against pi docs `prompt-templates.md` vs `skills.md`.

## 2026-10-07 — Fish + Starship + Catppuccin is interactive shell (preference) — `shell/fish`

- What: Interactive shell is `fish` with `starship`; abbrs (`g`, `gs`, `lg`, `y`, `cat→bat`, `ls→eza -la --icons --git`, `grep→rg`, `find→fd`), `fish_greeting` empty, Catppuccin Macchiato palette.
- Why: `home/shell.nix` is explicit on this; pi should match shell idioms when proposing commands.
- How: `home/shell.nix` `programs.fish.shellAbbrs` + `programs.starship`.

Source: `home/shell.nix`.

## 2026-10-07 — Commit style is conventional, focused (workflow) — `git/commit`

- What: Commit messages are `type(scope): summary` with optional body; diffs are inspected for secrets/accidental changes; commits are focused, never generic "changes"/"final".
- Why: `AGENTS.md` §12 + `pi/prompts/commit.md` legacy (removed but behaviour retained) — matches `git log` style.
- How: `git status`, `git diff`, secrets scan, then propose; wait for explicit confirmation before commit/push.

Source: `AGENTS.md` §12 + repo history.
