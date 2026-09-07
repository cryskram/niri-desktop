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

      # Bar — 3 ISLANDS (left/center/right) — Tokyo Night Storm per theme/tokens.nix
      # Left: launcher+workspaces (accent), Center: clock (surface), Right: system cluster (elevated)
      bar = {
        order = [ "main" ];
        main = {
          position = "top";
          thickness = 38;
          background_opacity = 0.0;
          radius = 14;
          margin_ends = 16;
          margin_edge = 10;
          padding = 8;
          widget_spacing = 10;
          shadow = true;
          reserve_space = true;
          capsule = false;
          capsule_radius = 10;
          # Left island — launcher + workspaces
          start = [
            "launcher"
            "workspaces"
          ];
          # Center island — clock alone (dots)
          center = [ "clock" ];
          # Right island — system cluster as one visual island (grouped via widget_spacing)
          end = [
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
