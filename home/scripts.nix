{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wl-mirror
    # get-sts — sanitized for GitHub (no account/MFA/domain hardcoded).
    # Create ~/.config/aws-sts.env from the example template and fill in:
    #   AWS_ACCOUNT_ID=<12-digit account id>
    #   AWS_MFA_USER=<iam user owning the MFA device>
    #   AWS_PROFILE=<profile holding the long-term IAM user key>
    #   AWS_CODEARTIFACT_DOMAIN=<codeartifact domain>
    #   AWS_CODEARTIFACT_DOMAIN_OWNER=<account id owning the domain>
    #   AWS_REGION=<region>
    # Optional: AWS_STS_TARGET_PROFILE=<profile for session creds, default: default>
    (writeShellScriptBin "get-sts" ''
      set -euo pipefail
      if [[ -z "''${1:-}" ]]; then echo "Usage: get-sts <MFA_CODE>"; exit 1; fi
      MFA_TOKEN="$1"
      # Load secrets from gitignored env (not committed)
      if [[ -f "$HOME/.config/aws-sts.env" ]]; then set -a; source "$HOME/.config/aws-sts.env"; set +a; fi
      : "''${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID in ~/.config/aws-sts.env}"
      : "''${AWS_MFA_USER:?Set AWS_MFA_USER in ~/.config/aws-sts.env}"

      # SOURCE holds the long-term IAM user key that owns the MFA device.
      # TARGET receives the temporary session credentials.
      #
      # These must never be the same profile. `source` above exports
      # AWS_PROFILE (set -a), and `aws configure set` writes to whatever
      # profile is active, so an unqualified write lands straight back in the
      # profile we just read from. That replaces the long-term key with a
      # session key, and the next run fails with:
      #   Cannot call GetSessionToken with session credentials
      # Unsetting the variables and passing --profile explicitly on every call
      # keeps the two apart, which is what makes this script repeatable.
      # AWS_PROFILE is required rather than defaulted: a default of "default"
      # would collide with TARGET_PROFILE and reintroduce the bug.
      : "''${AWS_PROFILE:?Set AWS_PROFILE in ~/.config/aws-sts.env}"
      : "''${AWS_CODEARTIFACT_DOMAIN:?Set AWS_CODEARTIFACT_DOMAIN in ~/.config/aws-sts.env}"
      SOURCE_PROFILE="$AWS_PROFILE"
      TARGET_PROFILE="''${AWS_STS_TARGET_PROFILE:-default}"
      unset AWS_PROFILE
      # An inherited session token would override the profile entirely.
      unset AWS_SESSION_TOKEN

      MFA_DEVICE="arn:aws:iam::''${AWS_ACCOUNT_ID}:mfa/''${AWS_MFA_USER}"
      DOMAIN="$AWS_CODEARTIFACT_DOMAIN"
      DOMAIN_OWNER="''${AWS_CODEARTIFACT_DOMAIN_OWNER:-$AWS_ACCOUNT_ID}"
      REGION="''${AWS_REGION:-ap-south-1}"
      DURATION=129600

      # Fail early and clearly instead of letting STS return a cryptic error.
      # AKIA = long-term IAM user key, ASIA = temporary session key.
      SRC_KEY=$(aws configure get aws_access_key_id --profile "$SOURCE_PROFILE" 2>/dev/null || true)
      SRC_TOKEN=$(aws configure get aws_session_token --profile "$SOURCE_PROFILE" 2>/dev/null || true)
      if [[ -z "$SRC_KEY" ]]; then
        echo "✗ Profile '$SOURCE_PROFILE' has no access key." >&2
        echo "  Add a long-term IAM user key (AWS console > IAM > Security credentials):" >&2
        echo "    aws configure set aws_access_key_id <KEY>    --profile $SOURCE_PROFILE" >&2
        echo "    aws configure set aws_secret_access_key <SECRET> --profile $SOURCE_PROFILE" >&2
        exit 1
      fi
      if [[ "$SRC_KEY" == ASIA* || -n "$SRC_TOKEN" ]]; then
        echo "✗ Profile '$SOURCE_PROFILE' holds temporary session credentials, not a long-term key." >&2
        echo "  GetSessionToken can only be called with a long-term IAM user key." >&2
        echo "  Replace them with a long-term key: delete the aws_session_token line" >&2
        echo "  from [$SOURCE_PROFILE] in ~/.aws/credentials, then:" >&2
        echo "    aws configure set aws_access_key_id <KEY>       --profile $SOURCE_PROFILE" >&2
        echo "    aws configure set aws_secret_access_key <SECRET> --profile $SOURCE_PROFILE" >&2
        exit 1
      fi

      echo "→ STS for $SOURCE_PROFILE → $TARGET_PROFILE ..."
      CREDS=$(aws sts get-session-token --duration-seconds $DURATION --serial-number "$MFA_DEVICE" --token-code "$MFA_TOKEN" --profile "$SOURCE_PROFILE" --output json)
      AK=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
      SK=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
      ST=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
      aws configure set aws_access_key_id "$AK" --profile "$TARGET_PROFILE"
      aws configure set aws_secret_access_key "$SK" --profile "$TARGET_PROFILE"
      aws configure set aws_session_token "$ST" --profile "$TARGET_PROFILE"
      aws configure set region "$REGION" --profile "$TARGET_PROFILE"
      echo "✅ STS credentials updated in [$TARGET_PROFILE] (36h)"
      if TOKEN=$(aws codeartifact get-authorization-token --profile "$TARGET_PROFILE" --domain "$DOMAIN" --domain-owner "$DOMAIN_OWNER" --region "$REGION" --query authorizationToken --output text 2>/dev/null); then
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
