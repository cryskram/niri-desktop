# Home-level theming — Tokyo Night Storm
# Imports centralized tokens; no hard-coded palette elsewhere per RICE §4.
{ pkgs, ... }:
let
  tokens = import ../theme/tokens.nix;
  c = tokens.colors;
  cn = tokens.colorsNoHash;
in
{
  # GTK — Tokyonight-Dark (closest to Storm in nixpkgs)
  gtk = {
    enable = true;
    theme = {
      package = pkgs.tokyonight-gtk-theme;
      name = "Tokyonight-Dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    font = {
      name = tokens.fonts.ui;
      size = tokens.fonts.size.sm;
    };
  };

  # Qt follows GTK
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "gtk2";
  };

  # Terminal — ghostty uses built-in TokyoNight Storm theme + mono font
  programs.ghostty.settings = {
    theme = "TokyoNight Storm";
    font-family = tokens.fonts.mono;
    font-size = 12;
    # Fallback explicit colors (ensures coherence even if theme missing)
    background = cn.background;
    foreground = cn.foreground;
    selection-background = cn.surface-elevated;
    selection-foreground = cn.foreground;
  };

  # Launcher — fuzzel (INI format)
  programs.fuzzel.settings = {
    main = {
      font = "${tokens.fonts.ui}:size=10";
      line-height = 18;
      horizontal-pad = 12;
      vertical-pad = 8;
      inner-pad = 8;
    };
    colors = {
      background = "${cn.background}ff";
      text = "${cn.foreground}ff";
      match = "${cn.accent-primary}ff";
      selection = "${cn.surface-elevated}ff";
      selection-text = "${cn.foreground}ff";
      border = "${cn.border}ff";
    };
    border = {
      width = 1;
      radius = 8;
    };
  };

  # Notifications — mako
  services.mako.settings = {
    background-color = "${c.background}";
    text-color = "${c.foreground}";
    border-color = "${c.border}";
    border-size = 1;
    border-radius = 8;
    default-timeout = 4000;
    # Urgency variants
    "urgency=high" = {
      background-color = "${c.surface}";
      border-color = "${c.error}";
      text-color = "${c.foreground}";
    };
  };
}
