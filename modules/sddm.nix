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
  };

  # Ensure SDDM can show the greeter on Wayland via cage (handled by sddm-astronaut's Main.qml)
  # No extra services needed — sddm-astronaut handles its own QML rendering.

  environment.systemPackages = with pkgs; [
    sddm-astronaut
  ];
}
