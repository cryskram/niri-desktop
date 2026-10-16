# Decision: DankMaterialShell (DMS) over Noctalia

**Date:** 2026-10-15
**Status:** Accepted — supersedes [`noctalia.md`](noctalia.md)

## Context

Noctalia served as the shell from 2026-09-06 (island bar, glass, launcher,
control center, notifications, wallpaper, lock) through the `noctalia` flake
input and its Home Manager module (`programs.noctalia.settings`, which writes
`~/.config/noctalia/config.toml`). Two costs accumulated:

- **Build cost:** noctalia is not in nixpkgs, so a flake update touching its
  input rebuilds it from source (~15 min). The "update one input at a time"
  discipline existed largely because of it.
- **Bar model:** the top-island bar was hand-tuned pill by pill. DMS 1.6 ships an
  island layout natively and a QML plugin API for the custom quota pill.

Alternatives considered:

1. **Stay on Noctalia** — no migration cost, config stays fully declarative, but
   keeps the source-build tax and the older feature set.
2. **Hand-rolled Quickshell bar** — already rejected (see `noctalia.md`): too
   much work for the polish required.
3. **DMS from nixpkgs** (chosen) — in nixpkgs with a NixOS module, cached binary,
   1.6 island layout, plugin API.

## Decision

Use DankMaterialShell 1.6.x from `nixpkgs-unstable` via the existing unstable
overlay, enabled through `programs.dms-shell` in `modules/dms-shell.nix`
(stable 26.05 only has 1.4.x, which lacks the island layout).

## Consequences

**The declarative boundary is different — read this before editing.**

- **Repo-owned:** the package/overlay pin, module options,
  `theme/dms-macchiato.json` (Catppuccin Macchiato mapped to DMS/matugen color
  keywords), niri keybinds and layer rules.
- **App-owned: `~/.config/DankMaterialShell/settings.json`** — bar layout, widget
  choices, theme selection. DMS rewrites this file from its own UI, so it is
  deliberately *not* a Home Manager symlink (a read-only store link would break
  every UI change). The module seeds it once — never overwriting — so a fresh
  system starts on the Macchiato theme.
- `DMS_DISABLE_MATUGEN=1` is set on `dms.service`: matugen would otherwise derive
  colors from the wallpaper and template compositor config fragments, fighting
  both the static palette and the declarative niri config.
- **Cost and quota reporting is third-party.** The repo's own quota pill
  (`dms-plugins/opencode-quota/` + `home/opencode-quota-fetch.nix`) was retired on
  2026-10-16 in favour of AiOverviewControl from the DMS plugin store, which
  covers both views. `OPENCODE_USAGE_SOURCE=api` is set on `dms.service` so its
  `opencode` card reports the Go-plan windows (rolling 5 h / weekly / monthly)
  rather than its default local mode, which reads opencode's own database and
  therefore cannot see pi traffic. Its `pi` card reads
  `~/.pi/agent/sessions/**/*.jsonl` locally (no network) and buckets each session
  to its start day, so marathon sessions under-report recent windows.
  Credential note: AiOverviewControl accepts `."opencode".key` in opencode's
  `auth.json`; the separate `aiQuotas` plugin instead wants `."opencode-go"` and
  an `opencode.db` `credential` row, neither of which exists on this machine.
- **Removed:** the `noctalia` flake input, `home/noctalia.nix`,
  `noctalia-plugins/opencode-quota/*.luau`, `theme/noctalia-macchiato.json`, and
  the `noctalia msg …` keybinds (now `dms ipc call …`, keeping the fuzzel /
  wlogout / swaylock fallbacks).
- **Locking:** idle and before-sleep now call DMS's lock with swaylock as the
  fallback (`home/ux.nix`); swaylock stays installed, so the security fallback is
  unchanged.
- **Wallpaper:** DMS owns it. `swaybg` and its niri `spawn-at-startup` were
  removed so two sources cannot fight over the background.
- **Trade-off accepted:** the bar layout lives in DMS's UI, not in git. If that
  becomes painful, snapshot the relevant `settings.json` keys into a repo-managed
  seed (the mechanism already exists in `modules/dms-shell.nix`).

## Rollback

`git revert` the migration commit and rebuild. Noctalia's input, module, palette
and plugin come back from history, and DMS leaves nothing outside
`~/.config/DankMaterialShell/`.
