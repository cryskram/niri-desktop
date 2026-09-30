# Centralized design tokens — Catppuccin Macchiato
# Single source of truth per RICE §4. Derived via catppuccin/nix + manual tokens.
rec {
  colors = {
    # Base
    background = "#24273a"; # base
    background-deep = "#1e2030"; # mantle
    background-darkest = "#181926"; # crust
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

    # Cursor + selection — Macchiato rosewater cursor, surface2 selection
    # (matches catppuccin's official terminal ports).
    cursor = "#f4dbd6"; # rosewater
    selectionBg = "#5b6078"; # surface2
    selectionFg = "#cad3f5"; # foreground

    # Full 16-slot ANSI terminal palette (0-7 dim, 8-15 bright). Brights use
    # the standard catppuccin mapping: 9-14 repeat 1-6, 8 = surface2,
    # 15 = subtext1.
    ansi = [
      "#494d64" # 0  black    (surface1)
      "#ed8796" # 1  red
      "#a6da95" # 2  green
      "#eed49f" # 3  yellow
      "#8aadf4" # 4  blue
      "#f5bde6" # 5  pink
      "#8bd5ca" # 6  teal
      "#a5adcb" # 7  white    (subtext0)
      "#5b6078" # 8  br-black (surface2)
      "#ed8796" # 9  br-red
      "#a6da95" # 10 br-green
      "#eed49f" # 11 br-yellow
      "#8aadf4" # 12 br-blue
      "#f5bde6" # 13 br-pink
      "#8bd5ca" # 14 br-teal
      "#b8c0e0" # 15 br-white (subtext1)
    ];
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
