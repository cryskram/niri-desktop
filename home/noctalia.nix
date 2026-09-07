# Noctalia — crazy beautiful r/unixporn shell, Tokyo Night Storm
# Glass, blur, capsule bar, Niri workspaces, Storm palette
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

    settings = {
      shell = {
        font_family = "JetBrainsMono Nerd Font";
        corner_radius_scale = 1.5;
        niri_overview_type_to_launch_enabled = false;
        clipboard_enabled = true;
        panel = {
          transparency_mode = "glass";
          borders = true;
          shadow = true;
        };
        animation = {
          enabled = true;
          speed = 1.2;
        };
        shadow = {
          direction = "down";
          alpha = 0.6;
        };
      };

      # Glass backdrop with blur — mission-control vibe
      backdrop = {
        enabled = true;
        blur_intensity = 0.6;
        tint_intensity = 0.2;
      };

      # Bar — floating ISLANDS, r/unixporn, Tokyo Night dots
      bar = {
        main = {
          position = "top";
          thickness = 36;
          background_opacity = 0.0;
          radius = 12;
          margin_ends = 10;
          margin_edge = 8;
          padding = 6;
          widget_spacing = 8;
          shadow = true;
          reserve_space = true;
          capsule = false;
          start = [
            "launcher"
            "workspaces"
          ];
          center = [ "clock" ];
          end = [
            "tray"
            "media"
            "network"
            "bluetooth"
            "volume"
            "battery"
            "control-center"
            "session"
          ];
        };
      };

      # Theme — Tokyo Night Storm
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Tokyo-Night";
        pure_black_dark = false;
      };

      # Notifications — glass toasts
      notification = {
        enable_daemon = true;
        show_app_name = true;
        background_opacity = 0.92;
        scale = 1.0;
      };
    };
  };

  programs.quickshell.enable = lib.mkForce false;
  programs.quickshell.systemd.enable = lib.mkForce false;
}
