# Catppuccin Macchiato — native NixOS/Home Manager integration
# Enables catppuccin/nix for all supported apps, flavor macchiato + mauve accent.
{
  lib,
  ...
}:
{
  catppuccin = {
    enable = true;
    flavor = "macchiato";
    accent = "mauve";
    autoEnable = true;
  };
  # Keep Astronaut login (more customized than catppuccin sddm)
  catppuccin.sddm.enable = false;

  # catppuccin's fish integration makes NixOS run
  #   fish_config theme choose "catppuccin-macchiato"
  # at every shell start. The .theme is colour-theme-aware — it has [dark] and
  # [light] sections — so fish picks the section from $fish_terminal_color_theme.
  # In terminals that do not answer the colour-scheme query (herdr panes,
  # script-created ptys) that variable is [unknown], and fish then errors with:
  #   failed to find '[unknown]' section (implied by $fish_terminal_color_theme)
  #   in 'catppuccin-macchiato' theme
  # Passing --color-theme=dark (this desktop is dark) selects the section
  # directly and also skips the on-variable hook that would otherwise re-apply
  # the theme whenever the detection changes.
  programs.fish.shellInit = lib.mkForce ''
    fish_config theme choose "catppuccin-macchiato" --color-theme=dark
  '';

  # Ensure GTK uses catppuccin (home will override, but system fallback)
  # Home Manager catppuccin will handle gtk, qt, etc. per user.
}
