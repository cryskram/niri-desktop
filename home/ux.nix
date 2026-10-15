# UX — screenshots, recording, power (RICE §26-27, §7)
# Clipboard, screenshots and the lock are DMS's (modules/dms-shell.nix).
# wl-clipboard kept for scriptable copy/paste; cliphist removed (redundant).
{ pkgs, ... }:
{
  # Idle — 5 min to lock + DPMS off (RICE §17), resume on input.
  # Lock goes through DMS with swaylock as the fallback when the shell is down
  # (same defensive chain as the Super+Alt+L keybind).
  services.swayidle = {
    enable = true;
    events = {
      before-sleep = "sh -c '${pkgs.dms-shell}/bin/dms ipc call lock lock || ${pkgs.swaylock}/bin/swaylock -f'";
    };
    timeouts = [
      {
        timeout = 300; # 5 min -> lock (DMS lock, swaylock fallback)
        command = "sh -c '${pkgs.dms-shell}/bin/dms ipc call lock lock || ${pkgs.swaylock}/bin/swaylock -f'";
      }
      {
        timeout = 305; # 5 sec after lock -> DPMS off, resume on input
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
        resumeCommand = "${pkgs.niri}/bin/niri msg action power-on-monitors";
      }
    ];
  };

  home.packages = with pkgs; [
    networkmanagerapplet # nm-applet for tray test (StatusNotifierItem)
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
