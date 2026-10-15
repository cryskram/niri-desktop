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

    # Quota pill — QML rewrite of the old Noctalia luau plugin. Same data source:
    # the opencode-quota-fetch timer writes ~/.cache/opencode-quota.json.
    plugins.opencode-quota.src = ../dms-plugins/opencode-quota;
  };

  # Static theme must win. Without this DMS regenerates colors from the wallpaper
  # through matugen and would also template compositor config fragments, which
  # would fight the declarative niri config.
  systemd.user.services.dms.environment.DMS_DISABLE_MATUGEN = "1";

  home-manager.users.vageesh = {
    xdg.configFile."DankMaterialShell/themes/catppuccin-macchiato.json".source =
      ../theme/dms-macchiato.json;

    # Seed DMS's own config, never overwriting it: DMS rewrites settings.json from
    # its UI, so only absent values get filled — the theme on a fresh install, and
    # the icon theme (Papirus-Dark with Catppuccin folders, from home/theme.nix).
    home.activation.dmsSeedSettings = ''
      cfg="$HOME/.config/DankMaterialShell/settings.json"
      mkdir -p "$(dirname "$cfg")"
      if [ ! -f "$cfg" ]; then
        printf '%s\n' '{ "currentThemeName": "custom", "customThemeFile": "${themeFile}" }' > "$cfg"
      fi
      tmp="$cfg.tmp"
      if ${pkgs.jq}/bin/jq '.iconThemeDark //= "Papirus-Dark"' "$cfg" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$cfg"
      else
        rm -f "$tmp"
      fi
    '';
  };
}
