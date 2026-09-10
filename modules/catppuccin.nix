# Catppuccin Mocha — native NixOS/Home Manager integration
# Enables catppuccin/nix for all supported apps, flavor mocha + mauve accent.
{
  catppuccin = {
    enable = true;
    flavor = "mocha";
    accent = "mauve";
    autoEnable = true;
  };
  # Keep Astronaut login (more customized than catppuccin sddm)
  catppuccin.sddm.enable = false;

  # Ensure GTK uses catppuccin (home will override, but system fallback)
  # Home Manager catppuccin will handle gtk, qt, etc. per user.
}
