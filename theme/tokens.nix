# Centralized design tokens — Catppuccin Macchiato
# Single source of truth per RICE §4. Derived via catppuccin/nix + manual tokens.
rec {
  colors = {
    # Base
    background = "#24273a"; # base
    background-deep = "#1e2030"; # mantle
    surface = "#363a4f"; # surface0
    surface-elevated = "#494d64"; # surface1
    surface-hover = "#5b6078"; # surface2
    surface-active = "#5b6078";

    # Foreground
    foreground = "#cad3f5"; # text
    foreground-muted = "#b8c0e0"; # subtext1
    foreground-dim = "#a5adcb"; # subtext0

    # Accent — catppuccin mauve + blue
    accent-primary = "#c6a0f6"; # mauve
    accent-secondary = "#8aadf4"; # blue

    # Borders
    border = "#494d64"; # surface1
    border-subtle = "#363a4f"; # surface0

    # Semantic
    success = "#a6da95"; # green
    warning = "#eed49f"; # yellow
    error = "#ed8796"; # red
    info = "#91d7e3"; # sky

    # Effects
    shadow = "#181926"; # crust
  };

  fonts = {
    ui = "Inter";
    mono = "JetBrains Mono";
    size = {
      xs = 9;
      sm = 10;
      md = 11;
      lg = 13;
    };
  };

  hexNoHash = hex: builtins.substring 1 (builtins.stringLength hex - 1) hex;
  colorsNoHash = builtins.mapAttrs (_: v: hexNoHash v) colors;
}
