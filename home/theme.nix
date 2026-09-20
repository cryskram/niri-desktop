# Home-level theming — Catppuccin Macchiato
# Imports centralized tokens; no hard-coded palette elsewhere per RICE §4.
{ pkgs, ... }:
let
  tokens = import ../theme/tokens.nix;
  cn = tokens.colorsNoHash;
in
{
  # GTK — Catppuccin Macchiato (via catppuccin/nix + catppuccin-gtk)
  gtk = {
    enable = true;
    theme = {
      package = pkgs.catppuccin-gtk.override {
        variant = "macchiato";
        accents = [ "mauve" ];
      };
      name = "catppuccin-macchiato-mauve-standard";
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

  # Cursor — Catppuccin Macchiato Mauve at 24px
  home.pointerCursor = {
    package = pkgs.catppuccin-cursors.macchiatoMauve;
    name = "catppuccin-macchiato-mauve-cursors";
    size = 24;
    x11.enable = true;
    gtk.enable = true;
  };

  home.sessionVariables = {
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "catppuccin-macchiato-mauve-cursors";
  };

  # Qt — use qt5ct on Wayland (gtk2 platform theme requires X DISPLAY and breaks Quickshell on pure Wayland)
  qt = {
    enable = true;
    platformTheme.name = "qt5ct";
  };

  # Terminal — ghostty Macchiato glass (more blur)
  programs.ghostty.settings = {
    font-family = tokens.fonts.mono;
    font-size = 11;
    theme = "Catppuccin Macchiato";
    # Sink the terminal below the rest of the desktop: crust instead of the
    # flavor's base. Ghostty applies explicit colors over theme colors, so the
    # Macchiato palette/accent set is kept and only the base is darkened.
    background = tokens.colors.background-darkest;
    cursor-text = tokens.colors.background-darkest;
    background-opacity = 0.82;
    # Canonical ghostty name for the blur intensity. Ghostty itself can only
    # apply this on macOS and KDE Plasma, so under niri it is inert: the blur
    # comes from niri's window-rule (home/niri.nix).
    background-blur = 32;
    # Focus is already communicated by niri's 2px mauve active border, so do not
    # also fade unfocused splits. Ghostty defaults unfocused-split-opacity to
    # 0.7, which paints a background-coloured rectangle over every split that
    # does not have focus (1 disables the effect entirely).
    unfocused-split-opacity = 1;
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
}
