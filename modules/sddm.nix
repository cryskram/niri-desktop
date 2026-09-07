# SDDM + Astronaut — highly customized Tokyo Night Storm login per RICE §16
# Futuristic, technical, GUI-based, shows NixOS/hostname/kernel/session/network/time
{
  pkgs,
  ...
}:
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    package = pkgs.kdePackages.sddm;
    # Cursor visible on login — keep astronaut theme, just add cursor (merge, don't replace Theme)
    settings.Theme.CursorTheme = "Bibata-Modern-Classic";
    settings.Theme.CursorSize = 24;
    # QtMultimedia/gst needed by sddm-astronaut (video background, effects) — fixes "QtMultimedia not found" error
    extraPackages = with pkgs; [
      bibata-cursors
      kdePackages.qtmultimedia
      kdePackages.qtsvg
      kdePackages.qtvirtualkeyboard
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
    ];
  };

  # Ensure SDDM can show the greeter on Wayland via cage (handled by sddm-astronaut's Main.qml)
  # No extra services needed — sddm-astronaut handles its own QML rendering.

  environment.systemPackages = with pkgs; [
    sddm-astronaut
  ];
}
