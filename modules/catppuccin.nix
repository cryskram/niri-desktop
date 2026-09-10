# Catppuccin Mocha — native NixOS/Home Manager integration
# Enables catppuccin/nix for all supported apps, flavor mocha + mauve accent.
{
  # Keep disabled for light flake check (manual Mocha tokens already active)
  # Enable when you want catppuccin/nix to theme bat/btop/etc.: set enable = true
  catppuccin = {
    enable = false;
    flavor = "mocha";
    accent = "mauve";
  };

  # Ensure GTK uses catppuccin (home will override, but system fallback)
  # Home Manager catppuccin will handle gtk, qt, etc. per user.
}
