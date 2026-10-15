# Desktop skeleton services (Home Manager).
#
# Phase 3: launcher, notifications, wallpaper, lock, terminal.
# DMS provides the shell (bar, panels, launcher, notifications, wallpaper, lock)
# via modules/dms-shell.nix — theme/noctalia-macchiato.json and the old noctalia
# luau plugin were replaced by theme/dms-macchiato.json and dms-plugins/.
{
  pkgs,
  ...
}:
let
  tokens = import ../theme/tokens.nix;
in
{
  # Launcher — fuzzel (Wayland-native, keyboard-first, matches niri default Mod+D)
  programs.fuzzel.enable = true;

  # Lock screen — swaylock (referenced by niri default Super+Alt+L)
  # PAM is configured at system level (modules/niri.nix). Themed Macchiato.
  programs.swaylock.enable = true;
  programs.swaylock.settings = {
    color = tokens.colorsNoHash.background;
    inside-color = tokens.colorsNoHash.surface;
    ring-color = tokens.colorsNoHash.border;
    inside-clear-color = tokens.colorsNoHash.surface;
    ring-clear-color = tokens.colorsNoHash.info;
    inside-ver-color = tokens.colorsNoHash.surface;
    ring-ver-color = tokens.colorsNoHash.warning;
    inside-wrong-color = tokens.colorsNoHash.surface;
    ring-wrong-color = tokens.colorsNoHash.error;
    key-hl-color = tokens.colorsNoHash.accent-primary;
    bs-hl-color = tokens.colorsNoHash.error;
    text-color = tokens.colorsNoHash.foreground;
    layout-bg-color = tokens.colorsNoHash.background-deep;
    separator-color = "00000000";
  };

  # Terminal — ghostty only (RICE §19) — Macchiato, blur/glass via the DMS theme
  programs.ghostty.enable = true;

  # Wallpaper is owned by DMS (its wallpaper service, see modules/dms-shell.nix).
  # swaybg used to be spawned by niri as a solid fallback; two wallpaper sources
  # fought over the background, so it is no longer installed or spawned.
}
