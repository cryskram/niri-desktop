# UX — screenshots, recording, power (RICE §26-27, §7)
# Clipboard is handled by Noctalia (home/noctalia.nix: clipboard_enabled).
# wl-clipboard kept for scriptable copy/paste; cliphist removed (redundant).
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wl-clipboard
    # Screenshots — grim + slurp (region), satty for annotation
    grim
    slurp
    satty
    # Recording — wf-recorder
    wf-recorder
    # Power / session
    wlogout
  ];
}
