# Home-level theming — Catppuccin Mocha
# Imports centralized tokens; no hard-coded palette elsewhere per RICE §4.
{ pkgs, ... }:
let
  tokens = import ../theme/tokens.nix;
  c = tokens.colors;
  cn = tokens.colorsNoHash;
in
{
  # GTK — Catppuccin Mocha (via catppuccin/nix + catppuccin-gtk)
  gtk = {
    enable = true;
    theme = {
      package = pkgs.catppuccin-gtk.override {
        variant = "mocha";
        accents = [ "mauve" ];
      };
      name = "catppuccin-mocha-mauve-standard";
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

  # Cursor — Catppuccin Mocha Mauve at 24px
  home.pointerCursor = {
    package = pkgs.catppuccin-cursors.mochaMauve;
    name = "catppuccin-mocha-mauve-cursors";
    size = 24;
    x11.enable = true;
    gtk.enable = true;
  };

  home.sessionVariables = {
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "catppuccin-mocha-mauve-cursors";
  };

  # Qt — use qt5ct on Wayland (gtk2 platform theme requires X DISPLAY and breaks Quickshell on pure Wayland)
  qt = {
    enable = true;
    platformTheme.name = "qt5ct";
  };

  # Terminal — ghostty Mocha glass (more blur)
  programs.ghostty.settings = {
    font-family = tokens.fonts.mono;
    font-size = 11;
    theme = "Catppuccin Mocha";
    background-opacity = 0.82;
    background-blur-radius = 32;
    window-decoration = false;
    window-padding-x = 12;
    window-padding-y = 12;
    copy-on-select = "clipboard";
  };

  # Launcher — fuzzel glass (transparent + blur via layer)
  programs.fuzzel.settings = {
    main = {
      font = "${tokens.fonts.ui}:size=10";
      line-height = 18;
      horizontal-pad = 12;
      vertical-pad = 8;
      inner-pad = 8;
      layer = "overlay";
    };
    colors = {
      background = "${cn.background}d9"; # d9 ~85% (glass)
      text = "${cn.foreground}ff";
      match = "${cn.accent-primary}ff";
      selection = "${cn.surface-elevated}cc"; # cc ~80%
      selection-text = "${cn.foreground}ff";
      border = "${cn.border}99"; # 60%
    };
    border = {
      width = 1;
      radius = 12;
    };
  };

  # Notifications — mako glass
  services.mako.settings = {
    background-color = "${c.background}d9";
    text-color = "${c.foreground}";
    border-color = "${c.border}99";
    border-size = 1;
    border-radius = 12;
    default-timeout = 4000;
    background-blur = true;
    # Urgency variants — keep glass
    "urgency=high" = {
      background-color = "${c.surface}e6";
      border-color = "${c.error}";
      text-color = "${c.foreground}";
    };
  };
}
