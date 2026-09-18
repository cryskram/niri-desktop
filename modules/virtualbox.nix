# VirtualBox host — personal (no vendor guest tools committed)
{ pkgs, ... }:
{
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = [ "vageesh" ];

  # Niri is Wayland — VirtualBox Qt5 needs XWayland. Enable it and ensure
  # Qt wayland platform is available so VirtualBox doesn't bail with
  # "No active display server, X11 or Wayland, detected."
  programs.xwayland.enable = true;
  environment.systemPackages = with pkgs; [
    libsForQt5.qtwayland
  ];
}
