# Centralized design tokens — Tokyo Night Storm
# Single source of truth per RICE §4. Changing the theme should require
# editing only this file (and derived configs via imports).
rec {
  colors = {
    # Base
    background = "#24283b";
    background-deep = "#1d202f";
    surface = "#292e42";
    surface-elevated = "#3b4261";
    surface-hover = "#414868";
    surface-active = "#3d59a1";

    # Foreground
    foreground = "#c0caf5";
    foreground-muted = "#a9b1d6";
    foreground-dim = "#787c99";

    # Accent
    accent-primary = "#7aa2f7";
    accent-secondary = "#bb9af7";

    # Borders
    border = "#3b4261";
    border-subtle = "#292e42";

    # Semantic
    success = "#9ece6a";
    warning = "#e0af68";
    error = "#f7768e";
    info = "#7dcfff";

    # Effects (keep as hex + manual alpha where needed)
    shadow = "#1a1b26";
    # glow is accent with alpha — composed in consumers
  };

  fonts = {
    ui = "Inter";
    mono = "JetBrains Mono";
    # Sizes follow a 4px scale; consumers pick as needed
    size = {
      xs = 9;
      sm = 10;
      md = 11;
      lg = 13;
    };
  };

  # Helper: strip leading # for apps that expect hex without it (ghostty, etc.)
  hexNoHash = hex: builtins.substring 1 (builtins.stringLength hex - 1) hex;

  # Convenience aliases for hex without #
  colorsNoHash = builtins.mapAttrs (_: v: hexNoHash v) colors;
}
