# Decision: Noctalia Shell over Custom Quickshell Bar

**Date:** 2026-09-06
**Status:** Accepted

## Context
RICE.md §6-7 originally specified a hand-rolled Quickshell bar with modular
`Bar / Workspaces / Window / Clock / Cpu / …` components. We implemented a
minimal bar (workspaces sorted, window title, CPU/RAM, network/audio/battery/
bluetooth/media, clock, floating panels) and it was functional but visually
generic — the user described it as “sooo bad” and requested a highly polished
r/unixporn look without rebuilding everything from scratch.

## Alternatives Considered
1. **Keep polishing custom Quickshell** — full control, but requires QML for
   every widget, panel, blur, and animation. Would take many more iterations to
   reach Noctalia’s level and risks fragile, unmaintained QML.
2. **Waybar** — proven, but still just a bar; we’d still need separate
   launcher (`fuzzel`), notifications (`mako`), wallpaper (`swaybg`), lock
   (`swaylock`), and panels.
3. **Noctalia** — single cohesive shell (bar, dock, launcher, control center,
   notifications, wallpaper, lock, clipboard, OSDs) built on Wayland + OpenGL ES
   with no Qt/GTK split, highly configurable via TOML, Niri workspaces native,
   Tokyo Night theming via settings, and hot-reload.

## Decision
Adopt **Noctalia** (`github:noctalia-dev/noctalia-shell`, also in
`nixpkgs#noctalia-shell` 4.7.6) as the desktop shell. Keep Niri as compositor,
`alacritty` as terminal, and `theme/tokens.nix` as the Storm source of truth;
Noctalia’s bar/panels replace the custom `quickshell/` bar. Custom
`quickshell/` is archived (removed from repo, kept in git history).

## Consequences
- **Positive:** Instant r/unixporn polish, fewer moving parts, one TOML for
  bar/dock/launcher/notifications/wallpaper/lock, consistent blur/transparency,
  Niri integration out of the box.
- **Negative:** Less hand-rolled QML, more TOML config; custom bar is now
  fallback/reference only.
- **Follow-up:** Tune `home/noctalia.nix` `settings` to pure Tokyo Night Storm
  (`#24283b` etc.), enable `swww` dynamic wallpaper, and keep `fuzzel`/`mako`
  as fallback.

## References
- RICE.md §6 Desktop Architecture, §7 Desktop Shell
- AGENTS.md §33 Architecture Decisions
