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

  # Qt — use qt5ct on Wayland (gtk2 platform theme requires X DISPLAY and breaks Quickshell on pure Wayland)
  qt = {
    enable = true;
    platformTheme.name = "qt5ct";
  };

  # Terminal — alacritty (Tokyo Night Storm)
  programs.alacritty.settings = {
    window = {
      padding = {
        x = 12;
        y = 12;
      };
      opacity = 0.95;
      decorations = "None";
    };
    font = {
      normal.family = tokens.fonts.mono;
      size = 11;
    };
    colors = {
      primary = {
        background = c.background;
        foreground = c.foreground;
      };
      normal = {
        black = c.background-deep;
        red = c.error;
        green = c.success;
        yellow = c.warning;
        blue = c.accent-primary;
        magenta = c.accent-secondary;
        cyan = c.info;
        white = c.foreground-muted;
      };
      bright = {
        black = c.surface-elevated;
        red = c.error;
        green = c.success;
        yellow = c.warning;
        blue = c.accent-primary;
        magenta = c.accent-secondary;
        cyan = c.info;
        white = c.foreground;
      };
      selection = {
        background = c.surface-elevated;
        text = c.foreground;
      };
    };
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
