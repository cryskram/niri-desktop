# VirtualBox host — personal (no vendor guest tools committed)
{ pkgs, ... }:
{
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = [ "vageesh" ];

  # Niri is Wayland — VirtualBox Qt5 needs XWayland. Niri autostarts
  # xwayland-satellite if it's in PATH and then sets DISPLAY=:0.
  # Without it, WAYLAND_DISPLAY=wayland-1 exists but DISPLAY is empty →
  # VirtualBox bails with "No active display server".
  programs.xwayland.enable = true;
  environment.systemPackages = with pkgs; [
    libsForQt5.qtwayland
    xwayland-satellite
    xwayland
  ];
}
