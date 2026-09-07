# Greetd + ReGreet — highly customized login per RICE §16
# Futuristic, technical, GUI-based, shows NixOS/hostname/kernel/graphics/session/network/time
{
  pkgs,
  ...
}:
{
  # Disable GDM (handled in configuration.nix) and enable greetd
  services.greetd.enable = true;

  programs.regreet = {
    enable = true;
    settings = {
      # Appearances — Tokyo Night Storm
      GTK.theme_name = "Tokyonight-Dark";
      GTK.icon_theme_name = "Papirus-Dark";
      GTK.cursor_theme_name = "Bibata-Modern-Classic";
      GTK.font_name = "Inter 11";
    };
    # Use cage as compositor for regreet (default)
    cageArgs = [
      "-s"
      "-d"
    ];
    theme = {
      package = pkgs.tokyonight-gtk-theme;
      name = "Tokyonight-Dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    font = {
      package = pkgs.inter;
      name = "Inter";
      size = 11;
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
    };
  };
}
