{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "niri-display-toggle" ''
      set -euo pipefail
      # Toggle HDMI-A-1 between extend (right of eDP, 2560x1440) and mirror (overlap 1920x1080)
      # Uses niri msg output (temporary, not persisted to config file).
      OUT="HDMI-A-1"
      JSON="$(niri msg -j outputs 2>/dev/null)"
      if ! echo "$JSON" | ${pkgs.jq}/bin/jq -e --arg o "$OUT" '.[$o]' >/dev/null 2>&1; then
        ${pkgs.libnotify}/bin/notify-send "Display" "$OUT not connected" 2>/dev/null || true
        exit 0
      fi
      X="$(echo "$JSON" | ${pkgs.jq}/bin/jq -r --arg o "$OUT" '.[$o].logical.x // 0')"
      # Duplicate = logical.x == 0 (overlaps eDP at 0,0). Extend = x ~1670.
      # Niri temporary position uses "position set X Y" (not "position x X y Y").
      if [ "$X" -eq 0 ] 2>/dev/null; then
        # → extend (HDMI right of eDP)
        niri msg output "$OUT" mode "2560x1440@59.951" 2>/dev/null || niri msg output "$OUT" mode "2560x1440" 2>/dev/null || true
        niri msg output "$OUT" scale 1.0 2>/dev/null || true
        niri msg output "$OUT" position set 1670 0 2>/dev/null || niri msg output "$OUT" position auto 2>/dev/null || true
        ${pkgs.libnotify}/bin/notify-send "Display" "Extend — eDP left, HDMI 2560×1440 right" 2>/dev/null || true
      else
        # → duplicate/mirror — niri does not truly mirror via overlap (auto-avoids overlap),
        # so we match eDP's mode/scale and put HDMI at same logical 0,0; if overlap is
        # rejected we fall back to HDMI off/on toggle (visually single).
        niri msg output "$OUT" mode "1920x1080" 2>/dev/null || true
        niri msg output "$OUT" scale 1.15 2>/dev/null || true
        if ! niri msg output "$OUT" position set 0 0 2>/dev/null; then
          niri msg output "$OUT" position auto 2>/dev/null || true
        fi
        # Verify if we actually overlapped — if still at 1670, niri rejected overlap
        sleep 0.3
        NX="$(niri msg -j outputs 2>/dev/null | ${pkgs.jq}/bin/jq -r --arg o "$OUT" '.[$o].logical.x // 0')"
        if [ "$NX" -eq 0 ] 2>/dev/null; then
          ${pkgs.libnotify}/bin/notify-send "Display" "Mirror — HDMI mirrors eDP (1920×1080 at 0,0)" 2>/dev/null || true
        else
          ${pkgs.libnotify}/bin/notify-send "Display" "Mirror requested — niri kept extend (no true mirror, use single)" 2>/dev/null || true
        fi
      fi
    '')
  ];
}
