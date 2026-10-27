# Dux Shell — Wayland shell, renamed from DankMaterialShell in nixpkgs 2026-10-20
# (`dms-shell` → `dux-shell`, 1.6.3 → 2.0.0). The `dms` binary, the `dms.service`
# unit and the IPC command names are unchanged, so keybinds and ux.nix still work.
#
# Package comes from nixpkgs-unstable via the overlay in modules/core.nix.
#
# Declarative boundary (deliberate): the shell rewrites ~/.config/dms/settings.json
# from its own UI, so the repo owns the *theme* and *plugins* while the bar layout
# and widget choices stay app-owned. The seed writes a file only when absent.
#
# 2.0.0 moved the config dir `~/.config/DankMaterialShell` → `~/.config/dms` (its
# own migration renames it, but Home Manager creates the new dir first, so the
# one-time move below has to happen here or a UI-made layout would be stranded).
{ lib, pkgs, ... }:
let
  tokens = import ../theme/tokens.nix;
  themeFile = "/home/vageesh/.config/dms/themes/catppuccin-macchiato.json";
in
{
  # Still `programs.dms-shell`: this repo takes the NixOS module from stable
  # 26.05, whose option names describe 1.6 (`enableDynamicTheming` etc.) and are
  # not renamed there. Renaming the *package* is what matters — the module only
  # wires dms.service, /etc/xdg/quickshell/dms-plugins and these helper packages.
  programs.dms-shell = {
    enable = true;
    package = pkgs.dux-shell;
    quickshell.package = pkgs.quickshell;

    # Helper binaries. 2.0.0's own module bundles these by default; the stable
    # module needs the flags, and without them dgop/cava/wtype are missing at
    # runtime (they are not in the package's PATH).
    enableSystemMonitoring = true; # dgop
    enableClipboardPaste = true; # wtype
    enableAudioWavelength = true; # cava
    enableVPN = true; # glib + NetworkManager

    # Installed but disabled at runtime (DMS_DISABLE_MATUGEN below): the rice is a
    # fixed Catppuccin Macchiato scheme, not wallpaper-derived.
    enableDynamicTheming = true;
  };

  # Static theme must win. Without this the shell regenerates colors from the
  # wallpaper through matugen and would also template compositor config fragments,
  # which would fight the declarative niri config. The variable name is unchanged
  # in 2.0.0 (verified in Theme.qml).
  systemd.user.services.dms.environment = {
    DMS_DISABLE_MATUGEN = "1";

    # AiOverviewControl's opencode card must read the Zen quota endpoint. Its
    # default (local) mode reads opencode's own database, which never sees pi
    # traffic — the usage that actually consumes this plan.
    OPENCODE_USAGE_SOURCE = "api";
  };

  home-manager.users.vageesh = {
    # One-time carry-over of the pre-2.0 config dir. Copies only what the new dir
    # lacks, so files Home Manager already owns are never overwritten; the old
    # path is left alone if anything unexpected remains in it.
    home.activation.dmsMigrateConfigDir = ''
      old="$HOME/.config/DankMaterialShell"
      new="$HOME/.config/dms"
      if [ -d "$old" ] && [ ! -L "$old" ]; then
        mkdir -p "$new"
        for entry in "$old"/* "$old"/.[!.]*; do
          [ -e "$entry" ] || continue
          name="$(basename "$entry")"
          [ -e "$new/$name" ] || mv "$entry" "$new/$name"
        done
        rmdir "$old" 2>/dev/null || true
      fi
    '';

    xdg.configFile."dms/themes/catppuccin-macchiato.json".source = ../theme/dms-macchiato.json;

    # Seed the shell's own config, never overwriting it: it rewrites settings.json
    # from its UI, so only absent values get filled — the theme on a fresh install,
    # and the icon theme (Tela-circle purple, from home/theme.nix).
    home.activation.dmsSeedSettings = ''
      cfg="$HOME/.config/dms/settings.json"
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
      plugin="$HOME/.config/dms/plugins/aiOverviewControl"
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
      cfg="$HOME/.config/dms/plugin_settings.json"
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
