# Centralized design tokens — Catppuccin Mocha
# Single source of truth per RICE §4. Derived via catppuccin/nix + manual tokens.
rec {
  colors = {
    # Base
    background = "#1e1e2e"; # base
    background-deep = "#181825"; # mantle
    surface = "#313244"; # surface0
    surface-elevated = "#45475a"; # surface1
    surface-hover = "#585b70"; # surface2
    surface-active = "#585b70";

    # Foreground
    foreground = "#cdd6f4"; # text
    foreground-muted = "#bac2de"; # subtext1
    foreground-dim = "#a6adc8"; # subtext0

    # Accent — catppuccin mauve + blue
    accent-primary = "#cba6f7"; # mauve
    accent-secondary = "#89b4fa"; # blue

    # Borders
    border = "#45475a"; # surface1
    border-subtle = "#313244"; # surface0

    # Semantic
    success = "#a6e3a1"; # green
    warning = "#f9e2af"; # yellow
    error = "#f38ba8"; # red
    info = "#89dceb"; # sky

    # Effects
    shadow = "#11111b"; # crust
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
