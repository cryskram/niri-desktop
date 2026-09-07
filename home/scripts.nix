{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wl-mirror
    (writeShellScriptBin "vpn-toggle" ''
      set -euo pipefail
      # Simple on/off for wg-quick-wg0 — no ip-link toggle logic per user request
      # Requires `secrets/wg0.conf` + `sudo nixos-rebuild switch` (unit wg-quick-wg0 must exist)
      SVC="wg-quick-wg0"
      if systemctl is-active --quiet "$SVC" 2>/dev/null; then
        echo "Stopping $SVC..."
        sudo systemctl stop "$SVC" 2>&1 || true
        notify-send "VPN" "VPN disconnected" 2>/dev/null || true
      else
        echo "Starting $SVC..."
        if ! sudo systemctl start "$SVC" 2>&1; then
          notify-send "VPN" "VPN failed — run: journalctl -u $SVC" 2>/dev/null || true
          exit 0
        fi
        sleep 0.5
        if systemctl is-active --quiet "$SVC" 2>/dev/null; then
          notify-send "VPN" "VPN connected" 2>/dev/null || true
        else
          notify-send "VPN" "VPN failed — check journalctl -u $SVC" 2>/dev/null || true
        fi
      fi
    '')
    (writeShellScriptBin "vpn-status" ''
      set -euo pipefail
      SVC="wg-quick-wg0"
      if systemctl is-active --quiet "$SVC" 2>/dev/null; then echo "up"; else echo "down"; fi
    '')
    (writeShellScriptBin "niri-display-toggle" ''
      set -euo pipefail
      OUT="HDMI-A-1"
      # True mirror via wl-mirror (niri has no overlapping mirror) — toggles a fullscreen
      # mirror of eDP-1 onto HDMI-A-1. Extend = side-by-side, Mirror = HDMI shows eDP content.
      if pgrep -x wl-mirror >/dev/null 2>&1; then
        pkill -x wl-mirror 2>/dev/null || killall wl-mirror 2>/dev/null || true
        # Restore HDMI to native extend
        niri msg output "$OUT" mode "2560x1440@59.951" 2>/dev/null || niri msg output "$OUT" mode "2560x1440" 2>/dev/null || true
        niri msg output "$OUT" scale 1.0 2>/dev/null || true
        niri msg output "$OUT" position set 1670 0 2>/dev/null || niri msg output "$OUT" position auto 2>/dev/null || true
        ${pkgs.libnotify}/bin/notify-send "Display" "Extend — eDP left, HDMI 2560×1440 right" 2>/dev/null || true
        exit 0
      fi
      # Not mirroring → check if HDMI connected, then start mirror
      JSON="$(niri msg -j outputs 2>/dev/null)"
      if ! echo "$JSON" | ${pkgs.jq}/bin/jq -e --arg o "$OUT" '.[$o]' >/dev/null 2>&1; then
        ${pkgs.libnotify}/bin/notify-send "Display" "$OUT not connected" 2>/dev/null || true
        exit 0
      fi
      # Ensure HDMI is in extend position first, then overlay mirror
      niri msg output "$OUT" mode "2560x1440@59.951" 2>/dev/null || niri msg output "$OUT" mode "2560x1440" 2>/dev/null || true
      niri msg output "$OUT" scale 1.0 2>/dev/null || true
      niri msg output "$OUT" position set 1670 0 2>/dev/null || niri msg output "$OUT" position auto 2>/dev/null || true
      # Start wl-mirror: mirror eDP-1 fullscreen onto HDMI-A-1, fit scaling
      # Note: output must be last arg, all options before it
      nohup wl-mirror --fullscreen-output "$OUT" --scaling fit eDP-1 >/dev/null 2>&1 &
      sleep 0.4
      if pgrep -x wl-mirror >/dev/null 2>&1; then
        ${pkgs.libnotify}/bin/notify-send "Display" "Mirror — HDMI shows eDP (wl-mirror, Mod+M to unmirror)" 2>/dev/null || true
      else
        ${pkgs.libnotify}/bin/notify-send "Display" "Mirror failed to start" 2>/dev/null || true
      fi
    '')
  ];
}
