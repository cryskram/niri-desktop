# Noctalia — polished Quickshell shell (RICE §7, replaces custom bar)
# Highly customizable, Tokyo Night Storm via settings, Niri workspaces native.
# Docs: https://docs.noctalia.dev/noctalia/configuration/
{
  lib,
  noctalia,
  ...
}:
{
  imports = [ noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    # Use the flake's package (follows nixpkgs 26.05 via inputs.nixpkgs.follows)
    # package is set via mkDefault in the module, no need to override

    settings = {
      shell = {
        font_family = "JetBrainsMono Nerd Font";
        corner_radius_scale = 1.0;
        # Niri integration
        niri_overview_type_to_launch_enabled = false;
        # Noctalia handles launcher, clipboard, wallpaper, lock, etc.
        clipboard_enabled = true;
        # Transparency mode: glass for floating panels per RICE §11
        panel = {
          transparency_mode = "glass";
          borders = true;
          shadow = true;
        };
      };

      # Bar — keep it floating, r/unixporn
      bar = {
        # Noctalia's bar is highly configurable; defaults are already floating.
        # We keep defaults and let the user tweak via Noctalia Settings GUI.
        # The bar will show workspaces, window, system, clock via its widgets.
      };

      # Theme — Tokyo Night Storm (Noctalia has Catppuccin built-in, Storm via custom)
      # For now use dark mode with Storm palette via custom colors;
      # Noctalia's GUI Settings can override at runtime.
      theme = {
        mode = "dark";
        # Noctalia 4.7+ supports custom themes via `custom` source, but we keep
        # builtin Catppuccin as close fallback and override via quickshell tokens
        # for now. Storm hexes are available via theme/tokens.nix for manual tweak.
      };
    };
  };

  # Keep our custom quickshell bar disabled when Noctalia is active to avoid duplicate bars.
  # The quickshell files remain in repo as fallback/reference.
  programs.quickshell.enable = lib.mkForce false;
  programs.quickshell.systemd.enable = lib.mkForce false;
}
