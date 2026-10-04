# OpenCode quota widget — topbar pill + popup
# Fetches https://opencode.ai/zen/go/v1/usage (rolling/weekly/monthly) via the
# opencode-go API key from ~/.pi/agent/auth.json and shows it as a
# Catppuccin Macchiato glass pill in the top bar. Click to expand.
{ pkgs, lib, ... }:
let
  fetchScript = pkgs.writeShellScriptBin "opencode-quota-fetch" ''
    set -euo pipefail
    KEY_FILE="$HOME/.pi/agent/auth.json"
    CACHE="$HOME/.cache/opencode-quota.json"
    TMP="$CACHE.tmp"
    mkdir -p "$(dirname "$CACHE")"
    if [ ! -f "$KEY_FILE" ]; then
      echo '{"usage":{"rolling":{"percent":0,"resetsAt":""},"weekly":{"percent":0,"resetsAt":""},"monthly":{"percent":0,"resetsAt":""}}}' > "$TMP"
      mv "$TMP" "$CACHE"
      exit 0
    fi
    KEY=$(${pkgs.jq}/bin/jq -r '.["opencode-go"].key // empty' "$KEY_FILE" 2>/dev/null || true)
    if [ -z "$KEY" ]; then
      echo '{"usage":{"rolling":{"percent":0,"resetsAt":""},"weekly":{"percent":0,"resetsAt":""},"monthly":{"percent":0,"resetsAt":""}}}' > "$TMP"
      mv "$TMP" "$CACHE"
      exit 0
    fi
    if ${pkgs.curl}/bin/curl -s --max-time 10 -H "Authorization: Bearer $KEY" https://opencode.ai/zen/go/v1/usage -o "$TMP" 2>/dev/null && ${pkgs.jq}/bin/jq -e '.usage' "$TMP" >/dev/null 2>&1; then
      mv "$TMP" "$CACHE"
    else
      rm -f "$TMP"
      # keep old cache if fetch failed
      [ -f "$CACHE" ] || echo '{"usage":{"rolling":{"percent":0,"resetsAt":""},"weekly":{"percent":0,"resetsAt":""},"monthly":{"percent":0,"resetsAt":""}}}' > "$CACHE"
    fi
  '';
in
{
  home.packages = with pkgs; [
    quickshell
    fetchScript
    jq
  ];

  # QML widget — glass pill + popup, Catppuccin Macchiato
  xdg.configFile."quickshell/opencode-quota/shell.qml".source = ../quickshell/opencode-quota/shell.qml;

  # also expose the fetch script as a plain file for debugging
  home.file.".local/bin/opencode-quota-fetch".source = "${fetchScript}/bin/opencode-quota-fetch";

  systemd.user.services.opencode-quota-fetch = {
    Unit.Description = "Fetch OpenCode quota (rolling/weekly/monthly)";
    Service = {
      Type = "oneshot";
      ExecStart = "${fetchScript}/bin/opencode-quota-fetch";
    };
  };

  systemd.user.timers.opencode-quota-fetch = {
    Unit.Description = "Refresh OpenCode quota every 5 minutes";
    Timer = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5m";
      Unit = "opencode-quota-fetch.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.opencode-quota-widget = {
    Unit = {
      Description = "OpenCode quota topbar widget (Quickshell)";
      After = [ "graphical-session.target" "opencode-quota-fetch.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs -c %h/.config/quickshell/opencode-quota";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Niri layer blur for the widget's PanelWindow (namespace quickshell)
  # The widget uses PanelWindow which creates a layer-shell surface; Niri can
  # blur layer surfaces via layer-rules. Match the widget's namespace.
  # Note: Quickshell PanelWindow defaults to layer "top" with namespace "quickshell"
  # — we could set a custom namespace in QML if needed.
}
