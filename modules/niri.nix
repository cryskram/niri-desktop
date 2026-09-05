# Niri Wayland compositor (system level).
#
# Phase 1 (Niri foundation):
# - registers the Niri session with GDM
# - enables xdg-desktop-portal with gnome/gtk backends (per upstream recommendation)
# - enables gnome-keyring for secrets
#
# Desktop UI (bar, launcher, notifications, lock) arrives in later phases.
# GNOME remains an available fallback session until the desktop is validated.
{
  pkgs,
  ...
}:
{
  programs.niri.enable = true;

  environment.systemPackages = with pkgs; [
    # Tools referenced by niri's default keybinds (media, brightness keys).
    # fuzzel / alacritty / swaylock are intentionally deferred to their own phases.
    brightnessctl
    playerctl
  ];
}
