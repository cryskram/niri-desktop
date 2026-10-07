# Context — niri-desktop for Pi

This is the runnable context for every pi session in this repo. Read it alongside `pi/skills/learnings/LEARNINGS.md` and `AGENTS.md`. It tells you what this repo is, how it is laid out, and how to work in it without re-discovery.

## What this repo is

Reproducible NixOS desktop/workstation around **Niri** (scrollable tiling) + **Noctalia** (Quickshell shell) — Catppuccin Macchiato, Wayland-native, on `nixos-26.05`. The Git repo is the **single source of truth**; `nixos-rebuild` reproduces the system from `flake.nix`. See `README.md`, `AGENTS.md` (§2 Source of Truth), and `RICE.md` for the visual spec.

## Stack & pins

- **Nix:** `nixpkgs` `nixos-26.05`, `nixpkgs-unstable` (overlays `pi`, `opencode`, `herdr`), `home-manager` `release-26.05`, `pi` via `lukasl-dev/pi.nix`, `noctalia`, `catppuccin`, `spicetify-nix`.
- **Compositor/shell:** Niri (config validated by `nix flake check`), Noctalia/QML islands, SDDM Astronaut, Catppuccin tokens (`theme/tokens.nix`).
- **Pi:** Declarative via `modules/core.nix` (`programs.pi.coding-agent`): `pi/rules.md` → `--append-system-prompt`, `pi/skills/` → `--skill`, `pi/extensions/*.ts` → `--extension`, `pi/themes/` → `--theme`. Office skills live outside the repo (`~/Projects/TAP/...`) via `extraArgs --skill` — do not duplicate. Quick `pi --list` should show `mcp-adapter, pi-btw, rpiv-*, zentui, pi-subagents, pi-web-access`.
- **Dev:** `devenv` + `direnv` + Docker; language toolchains (Go/Java/Node/Python/Rust) and apps (Ghostty, Chrome, Slack, etc.) via `home/development.nix` + `applications.nix`.

## Layout (where things live)

```
flake.nix / configuration.nix / hardware-configuration.nix
modules/{core,theme,shell,niri,sddm,docker,direnv,vpn}.nix   # system
home/{niri,shell,development,git,direnv,...}.nix              # HM user
theme/tokens.nix + noctalia-macchiato.json                    # tokens
pi/rules.md, pi/context.md, pi/skills/, pi/extensions/, pi/themes/  # pi declarative
dev/{shared,templates,company}/                               # personal devenvs (company stays detached)
```

## How to work (declarative workflow)

1. **Inspect** repo + relevant module before editing (AGENTS.md §4).
2. **Small change** through the flake/module structure — never `~/.pi` imperative edits. Company `dev/company/*.nix` never touches company repos directly.
3. **Validate** `nix flake check` and `nixos-rebuild dry-build --flake .#nixos` before claiming success.
4. **Format** with `nix fmt` (nixfmt). No competing formatters.
5. **Git**: `git status/diff` before commit; conventional commits `type(scope): summary`; scan for secrets; never `reset --hard`/`push -f` without confirmation.
6. **Flake inputs**: update one at a time with dry-run cost preview (`nix build --dry-run ... | grep drv`); `noctalia` always rebuilds (~15min). See README § Updating inputs.

## Pi conventions

- **Memory**: `pi/skills/learnings/` is the journal (`SKILL.md` = instructions, `LEARNINGS.md` = data). Read at start, append on signal — `pi/rules.md` § Memory enforces it.
- **Discovery**: Prefer `repo-understanding` for unfamiliar areas before coding; use `learnings` for preferences. Prompt templates (`pi/prompts/`) are intentionally empty — skills are the mechanism.
- **Extensions**: `safety.ts` (destructive-command gate) + `querion-sync.ts` (`/sync`) are local; third-party are pinned in `pi/packages.nix` (withDeps pattern). Update via `scripts/update-pi-extensions.py`.
- **MCP**: `dummy` harness via `pi/mcp-servers/dummy` (pure derivation, pinned npmHash). `pi-web-access` gives `web_search/fetch/source_check` to subagents; parallel-search via MCP is separate namespace.

## Quick commands

```bash
nix flake check
nixos-rebuild dry-build --flake .#nixos
pi --list; pi --version
scripts/update-pi-extensions.py --check
```

## When unsure, check in order

1. `pi/skills/learnings/LEARNINGS.md` → prior decisions/preferences
2. `AGENTS.md` (+ `docs/decisions/*.md`) → architecture & policy
3. `README.md` / `RICE.md` / `DEV_ENVIRONMENT.md` → spec & dev setup
4. `modules/core.nix` → how pi is wired

Update this file when stack/layout/conventions change meaningfully; keep it <100 lines — detail belongs in `AGENTS.md`/`LEARNINGS.md`.
