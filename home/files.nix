# File management — Yazi (terminal) + Nautilus (graphical) (RICE §21)
# Both integrate with Storm where practical; Nautilus already provided via
# programs.niri.useNautilus + gnome.dbus.packages
{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      manager.show_hidden = true;
      preview.image_filter = "lanczos";
    };
  };

  # Graphical — Nautilus is already available via NixOS niri module (useNautilus=true)
  # Ensure it and its deps are in PATH for file-chooser portal
  home.packages = with pkgs; [
    nautilus
    file-roller
    loupe # Image Viewer (Wayland-native, handles all formats; satty stays for annotation)
  ];

  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/jpg" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
    };
    defaultApplications = {
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/jpg" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
    };
  };
}
