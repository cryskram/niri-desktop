# OpenCode quota fetcher — systemd timer that keeps ~/.cache/opencode-quota.json fresh
# for the Noctalia plugin (noctalia-plugins/opencode-quota). Also useful for debugging.
{ pkgs, ... }:
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
      [ -f "$CACHE" ] || echo '{"usage":{"rolling":{"percent":0,"resetsAt":""},"weekly":{"percent":0,"resetsAt":""},"monthly":{"percent":0,"resetsAt":""}}}' > "$CACHE"
    fi
  '';
in
{
  home.packages = [ fetchScript pkgs.jq ];

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
}
