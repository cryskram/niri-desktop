# Desktop skeleton services (Home Manager).
#
# Phase 3: launcher, notifications, wallpaper, lock, quickshell, terminal.
# Theme (Tokyo Night Storm) and visual polish land in Phase 4.
# All services are intentionally minimal here — correctness first.
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

  # Notifications — mako (lightweight Wayland compositor notifications)
  # Runs as a systemd user service; a failure must not crash the shell.
  services.mako.enable = true;

  # Lock screen — swaylock (referenced by niri default Super+Alt+L)
  # PAM is configured at system level (modules/niri.nix). Themed Storm.
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

  # Terminal — alacritty (primary per user preference, RICE §19).
  # Ghostty remains available in nixpkgs for evaluation (`nix shell nixpkgs#ghostty`).
  programs.alacritty.enable = true;

  # Wallpaper — swaybg (static fallback, per RICE §18)
  # Spawned via niri's spawn-at-startup (see home/niri.nix) so it is tied
  # to the compositor lifecycle. Installed to PATH so the spawn succeeds.
  home.packages = with pkgs; [
    swaybg
  ];

  # Desktop shell toolkit — quickshell (modular QML shell, RICE §7)
  # Starts as a systemd user service tied to the niri session.
  programs.quickshell.enable = true;
  programs.quickshell.systemd.enable = true;
  programs.quickshell.systemd.target = "graphical-session.target";
  programs.quickshell.configs."niri-desktop" = ../quickshell;
  programs.quickshell.activeConfig = "niri-desktop";
}
