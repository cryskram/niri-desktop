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
  ];

  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "image/png" = "satty.desktop";
      "image/jpeg" = "satty.desktop";
      "image/jpg" = "satty.desktop";
      "image/webp" = "satty.desktop";
      "image/gif" = "satty.desktop";
      "image/bmp" = "satty.desktop";
    };
    defaultApplications = {
      "image/png" = "satty.desktop";
      "image/jpeg" = "satty.desktop";
      "image/jpg" = "satty.desktop";
      "image/webp" = "satty.desktop";
      "image/gif" = "satty.desktop";
      "image/bmp" = "satty.desktop";
    };
  };
}
