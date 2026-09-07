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

  # Cursor — Bibata Modern Classic at 24px (was abnormally big at default 32)
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    x11.enable = true;
    gtk.enable = true;
  };

  home.sessionVariables = {
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "Bibata-Modern-Classic";
  };

  # Qt — use qt5ct on Wayland (gtk2 platform theme requires X DISPLAY and breaks Quickshell on pure Wayland)
  qt = {
    enable = true;
    platformTheme.name = "qt5ct";
  };

  # Terminal — ghostty Storm, blur/glass via Noctalia
  programs.ghostty.settings = {
    font-family = tokens.fonts.mono;
    font-size = 11;
    theme = "TokyoNight Storm";
    background-opacity = 0.92;
    background-blur-radius = 20;
    window-decoration = false;
    window-padding-x = 12;
    window-padding-y = 12;
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
