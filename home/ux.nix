# UX — clipboard, screenshots, recording, power (RICE §26-27, §7)
# All Wayland-native, Niri-compatible, failure-independent.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Clipboard — Wayland clipboard + history
    wl-clipboard
    cliphist
    # Screenshots — grim + slurp (region), satty for annotation
    grim
    slurp
    satty
    # Recording — wf-recorder (lightweight) + gpu-screen-recorder for high perf
    wf-recorder
    # Power / session
    wlogout
  ];

  # Clipboard history daemon — cliphist stores, wl-paste watches
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # Ensure cliphist + wl-clipboard integration via systemd user service is handled by HM
  # HM's cliphist module already sets up the service; no extra config needed.
}
