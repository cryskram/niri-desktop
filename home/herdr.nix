# Herdr — terminal workspace for coding agents, Catppuccin Macchiato
# Makes questions, errors, and working states pop with Macchiato pastels.
{
  pkgs,
  ...
}:
{
  # Herdr is installed via home.packages in development.nix, but its config
  # at ~/.config/herdr/config.toml is otherwise imperative. We take it over
  # declaratively so the colors for asking/error/working are always right.
  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false

    [ui]
    status_indicators = "symbols"

    [ui.toast]
    # "terminal" keeps toasts inside the Herdr TUI (less intrusive than
    # system notifications, but still visible). Use "notification" to also
    # send to mako/Noctalia.
    delivery = "terminal"

    [theme]
    name = "catppuccin"
    auto_switch = false

    # Herdr's "catppuccin" is Mocha; override to Macchiato to match the
    # desktop (base #24273a, not #1e1e2e). These are the Macchiato pastels
    # that make "asking" vs "error" vs "working" instantly distinct.
    [theme.custom]
    # core surfaces
    panel_bg = "#24273a"
    sidebar_bg = "#1e2030"
    surface0 = "#363a4f"
    # accents — match tokens.nix
    accent = "#c6a0f6"      # mauve — active/asking
    green = "#a6da95"       # done/success
    blue = "#8aadf4"        # info
    red = "#ed8796"         # blocked/error — vivid but not harsh
    yellow = "#eed49f"      # working — warm, visible
    teal = "#8bd5ca"        # done alternative
    peach = "#f5a97f"
  '';
}
