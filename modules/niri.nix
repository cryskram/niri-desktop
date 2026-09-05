# Niri Wayland compositor (system level).
#
# Phase 1 (Niri foundation) + Phase 3 (Desktop skeleton):
# - registers the Niri session with GDM
# - enables xdg-desktop-portal with gnome/gtk backends (per upstream recommendation)
# - enables gnome-keyring for secrets
# - PAM for swaylock (Phase 3 lock screen, niri default Super+Alt+L)
#
# GNOME remains an available fallback session until the desktop is validated.
{
  pkgs,
  ...
}:
{
  programs.niri.enable = true;

  # PAM must be configured for swaylock to authenticate (HM programs.swaylock).
  security.pam.services.swaylock = { };

  environment.systemPackages = with pkgs; [
    # Tools referenced by niri's default keybinds (media, brightness keys).
    brightnessctl
    playerctl
  ];
}
