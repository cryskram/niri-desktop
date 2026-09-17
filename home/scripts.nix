{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wl-mirror
    # get-sts — sanitized for GitHub (no account/MFA hardcoded). Real values in ~/.config/aws-sts.env (gitignored)
    # Create ~/.config/aws-sts.env from ~/.config/aws-sts.env.example and fill:
    #   AWS_ACCOUNT_ID=313208865236
    #   AWS_MFA_USER=vageesh.gn
    #   AWS_PROFILE=vageesh.gn
    #   AWS_CODEARTIFACT_DOMAIN=ppipl
    #   AWS_CODEARTIFACT_DOMAIN_OWNER=313208865236
    #   AWS_REGION=ap-south-1
    (writeShellScriptBin "get-sts" ''
      set -euo pipefail
      if [[ -z "''${1:-}" ]]; then echo "Usage: get-sts <MFA_CODE>"; exit 1; fi
      MFA_TOKEN="$1"
      # Load secrets from gitignored env (not committed)
      if [[ -f "$HOME/.config/aws-sts.env" ]]; then set -a; source "$HOME/.config/aws-sts.env"; set +a; fi
      : "''${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID in ~/.config/aws-sts.env}"
      : "''${AWS_MFA_USER:?Set AWS_MFA_USER in ~/.config/aws-sts.env}"
      : "''${AWS_PROFILE:?Set AWS_PROFILE in ~/.config/aws-sts.env}"
      MFA_DEVICE="arn:aws:iam::''${AWS_ACCOUNT_ID}:mfa/''${AWS_MFA_USER}"
      PROFILE="''${AWS_PROFILE}"
      DOMAIN="''${AWS_CODEARTIFACT_DOMAIN:-ppipl}"
      DOMAIN_OWNER="''${AWS_CODEARTIFACT_DOMAIN_OWNER:-$AWS_ACCOUNT_ID}"
      REGION="''${AWS_REGION:-ap-south-1}"
      DURATION=129600
      echo "→ STS for $PROFILE ..."
      CREDS=$(aws sts get-session-token --duration-seconds $DURATION --serial-number "$MFA_DEVICE" --token-code "$MFA_TOKEN" --profile "$PROFILE" --output json)
      AK=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
      SK=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
      ST=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
      aws configure set aws_access_key_id "$AK"
      aws configure set aws_secret_access_key "$SK"
      aws configure set aws_session_token "$ST"
      echo "✅ STS credentials updated (36h)"
      if TOKEN=$(aws codeartifact get-authorization-token --domain "$DOMAIN" --domain-owner "$DOMAIN_OWNER" --region "$REGION" --query authorizationToken --output text 2>/dev/null); then
        export CODEARTIFACT_AUTH_TOKEN="$TOKEN"
        export ENVIRONMENT=development
        echo "✅ CodeArtifact token: ''${TOKEN:0:12}..."
        echo "   export CODEARTIFACT_AUTH_TOKEN=$TOKEN"
      else
        echo "⚠ STS ok, CodeArtifact failed (check aws config)"
      fi
      EXP=$(echo "$CREDS" | jq -r '.Credentials.Expiration')
      echo "   Expires: $EXP"
      notify-send "AWS STS" "Updated — expires $EXP" 2>/dev/null || true
    '')
    (writeShellScriptBin "vpn-toggle" ''
      set -euo pipefail
      # Toggle VPN — matches Noctalia (NetworkManager wg0), fallback to wg-quick if present
      CONN="wg0"
      SVC="wg-quick-wg0"
      # Prefer NM if connection exists (what Noctalia toggles)
      if nmcli connection show "$CONN" >/dev/null 2>&1; then
        if nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -q "^wireguard:connected"; then
          echo "Stopping NM $CONN..."
          nmcli connection down "$CONN" 2>&1 || true
          notify-send "VPN" "VPN disconnected" 2>/dev/null || true
        else
          echo "Starting NM $CONN..."
          if nmcli connection up "$CONN" 2>&1; then
            notify-send "VPN" "VPN connected" 2>/dev/null || true
          else
            notify-send "VPN" "VPN failed — check nmcli" 2>/dev/null || true
          fi
        fi
        exit 0
      fi
      # Fallback wg-quick (if NM not used)
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
      CONN="wg0"
      SVC="wg-quick-wg0"
      if nmcli connection show "$CONN" >/dev/null 2>&1; then
        if nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -q "^wireguard:connected"; then echo "up"; else echo "down"; fi
      else
        if systemctl is-active --quiet "$SVC" 2>/dev/null; then echo "up"; else echo "down"; fi
      fi
    '')
    (writeShellScriptBin "niri-display-toggle" ''
      set -euo pipefail
      OUT="HDMI-A-1"
      # If called with 1 or 2 -> force left/right extend (no mirror toggle)
      if [ "''${1:-}" = "1" ]; then
        pkill -x wl-mirror 2>/dev/null || true
        niri msg output "$OUT" mode "2560x1440@59.951" 2>/dev/null || niri msg output "$OUT" mode "2560x1440" 2>/dev/null || true
        niri msg output "$OUT" scale 1.0 2>/dev/null || true
        niri msg output "$OUT" position set 0 0 2>/dev/null || true
        niri msg output "eDP-1" position set 2560 0 2>/dev/null || true
        ${pkgs.libnotify}/bin/notify-send "Display" "Extend — HDMI left, eDP right (1)" 2>/dev/null || true
        exit 0
      fi
      if [ "''${1:-}" = "2" ]; then
        pkill -x wl-mirror 2>/dev/null || true
        niri msg output "eDP-1" position set 0 0 2>/dev/null || true
        niri msg output "$OUT" mode "2560x1440@59.951" 2>/dev/null || niri msg output "$OUT" mode "2560x1440" 2>/dev/null || true
        niri msg output "$OUT" scale 1.0 2>/dev/null || true
        niri msg output "$OUT" position set 1670 0 2>/dev/null || niri msg output "$OUT" position auto 2>/dev/null || true
        ${pkgs.libnotify}/bin/notify-send "Display" "Extend — eDP left, HDMI right (2)" 2>/dev/null || true
        exit 0
      fi
      # True mirror via wl-mirror — toggles mirror vs extend (extend side via menu)
      if pgrep -x wl-mirror >/dev/null 2>&1; then
        pkill -x wl-mirror 2>/dev/null || killall wl-mirror 2>/dev/null || true
        # Was mirror -> ask left/right for extend
        CHOICE=$(printf "2 Right (eDP left)\n1 Left (HDMI left)" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Extend side: " 2>/dev/null || echo "2")
        if echo "$CHOICE" | grep -q "^1"; then
          niri msg output "$OUT" mode "2560x1440@59.951" 2>/dev/null || niri msg output "$OUT" mode "2560x1440" 2>/dev/null || true
          niri msg output "$OUT" scale 1.0 2>/dev/null || true
          niri msg output "$OUT" position set 0 0 2>/dev/null || true
          niri msg output "eDP-1" position set 2560 0 2>/dev/null || true
          ${pkgs.libnotify}/bin/notify-send "Display" "Extend — HDMI left, eDP right (1)" 2>/dev/null || true
        else
          niri msg output "eDP-1" position set 0 0 2>/dev/null || true
          niri msg output "$OUT" mode "2560x1440@59.951" 2>/dev/null || niri msg output "$OUT" mode "2560x1440" 2>/dev/null || true
          niri msg output "$OUT" scale 1.0 2>/dev/null || true
          niri msg output "$OUT" position set 1670 0 2>/dev/null || niri msg output "$OUT" position auto 2>/dev/null || true
          ${pkgs.libnotify}/bin/notify-send "Display" "Extend — eDP left, HDMI right (2)" 2>/dev/null || true
        fi
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
