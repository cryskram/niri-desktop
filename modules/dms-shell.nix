# DankMaterialShell — Wayland shell replacing Noctalia (RICE §13).
#
# Package comes from nixpkgs-unstable via the overlay in modules/core.nix:
# stable 26.05 ships 1.4.x, 1.6.x adds the island bar layout this rice uses.
#
# Declarative boundary (deliberate): DMS rewrites ~/.config/DankMaterialShell/settings.json
# from its own UI, so the repo owns the *theme* and *plugins* while the bar layout
# and widget choices stay app-owned. The seed below only writes the file when it
# does not exist yet — never overwriting what the UI saved.
{ lib, pkgs, ... }:
let
  tokens = import ../theme/tokens.nix;
  themeFile = "/home/vageesh/.config/DankMaterialShell/themes/catppuccin-macchiato.json";
in
{
  programs.dms-shell = {
    enable = true;
    package = pkgs.dms-shell;
    quickshell.package = pkgs.quickshell;

    # Helper packages the module gates behind options (the 1.6 module adds these
    # unconditionally): system monitors, clipboard paste, audio visualizer, VPN.
    enableSystemMonitoring = true; # dgop
    enableClipboardPaste = true; # wtype
    enableAudioWavelength = true; # cava
    enableVPN = true; # glib + NetworkManager

    # Kept installed but disabled at runtime (DMS_DISABLE_MATUGEN below): the rice
    # is a fixed Catppuccin Macchiato scheme, not wallpaper-derived.
    enableDynamicTheming = true;
  };

  # Static theme must win. Without this DMS regenerates colors from the wallpaper
  # through matugen and would also template compositor config fragments, which
  # would fight the declarative niri config.
  systemd.user.services.dms.environment = {
    DMS_DISABLE_MATUGEN = "1";

    # AiOverviewControl's opencode card must read the Zen quota endpoint. Its
    # default (local) mode reads opencode's own database, which never sees pi
    # traffic — the usage that actually consumes this plan.
    OPENCODE_USAGE_SOURCE = "api";
  };

  home-manager.users.vageesh = {
    xdg.configFile."DankMaterialShell/themes/catppuccin-macchiato.json".source =
      ../theme/dms-macchiato.json;

    # Seed DMS's own config, never overwriting it: DMS rewrites settings.json from
    # its UI, so only absent values get filled — the theme on a fresh install, and
    # the icon theme (Tela-circle purple, from home/theme.nix).
    home.activation.dmsSeedSettings = ''
      cfg="$HOME/.config/DankMaterialShell/settings.json"
      mkdir -p "$(dirname "$cfg")"
      if [ ! -f "$cfg" ]; then
        printf '%s\n' '{ "currentThemeName": "custom", "customThemeFile": "${themeFile}" }' > "$cfg"
      fi
      tmp="$cfg.tmp"
      # `//=` fills an absent value; the equality test migrates the value this
      # module seeded before (Papirus-Dark) without touching a UI-made choice.
      if ${pkgs.jq}/bin/jq --arg name "${tokens.icons.name}" '
           .iconThemeDark = (if (.iconThemeDark // "Papirus-Dark") == "Papirus-Dark" then $name else .iconThemeDark end)
         ' "$cfg" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$cfg"
      else
        rm -f "$tmp"
      fi
    '';

    # AiOverviewControl 1.21.0 validates the pre-2026-10 Zen quota shape
    # (rollingUsage/usagePercent/resetInSec); the endpoint now answers with
    # usage.{rolling,weekly,monthly}.{percent,resetsAt}, so its opencode card
    # degraded to an auth-only note. The patch accepts both shapes. Re-applied on
    # every activation because the plugin store can replace the file, and skipped
    # once the file already handles the current shape (our patch or upstream's).
    home.activation.patchAiOverviewControlOpencode = ''
      plugin="$HOME/.config/DankMaterialShell/plugins/aiOverviewControl"
      adapter="$plugin/providers/native/opencode.bash"
      if [ -f "$adapter" ] && ! grep -q 'current_shape' "$adapter"; then
        if ${pkgs.patch}/bin/patch --forward --silent -p1 -d "$plugin" \
             < ${../patches/aioc-opencode-usage-shape.patch}; then
          echo "AiOverviewControl: opencode adapter patched for the current Zen usage shape"
        else
          echo "AiOverviewControl: opencode adapter patch FAILED — upstream may have changed it" >&2
        fi
      fi
    '';

    # The API-backed opencode card replaces the local pi card: pi's numbers come
    # from ~/.pi/agent/sessions/**/*.jsonl bucketed to each session's start day, so
    # a long session under-reports recent windows. `pi` is what was in place before
    # this change; any other selection is a UI choice and is left alone.
    home.activation.dmsSeedPluginSettings = ''
      cfg="$HOME/.config/DankMaterialShell/plugin_settings.json"
      if [ -f "$cfg" ]; then
        tmp="$cfg.tmp"
        if ${pkgs.jq}/bin/jq '
             if .aiOverviewControl then
               (.aiOverviewControl.providerSelection =
                  (if (.aiOverviewControl.providerSelection // "pi") == "pi" then "opencode" else .aiOverviewControl.providerSelection end)
                | .aiOverviewControl.pillProviders =
                  (if (.aiOverviewControl.pillProviders // "pi") == "pi" then "opencode" else .aiOverviewControl.pillProviders end))
             else . end
           ' "$cfg" > "$tmp" 2>/dev/null; then
          mv "$tmp" "$cfg"
        else
          rm -f "$tmp"
        fi
      fi
    '';
  };
}
