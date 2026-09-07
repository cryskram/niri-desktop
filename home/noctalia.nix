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

      # Bar — TRUE ISLANDS: no bar background, each pill its own Storm color
      bar = {
        order = [ "main" ];
        default.enabled = false;
        main = {
          position = "top";
          thickness = 36;
          background_opacity = 0.0;
          radius = 0;
          margin_ends = 12;
          margin_edge = 8;
          padding = 0;
          widget_spacing = 10;
          shadow = false;
          reserve_space = true;
          border_width = 0.0;
          capsule = true;
          capsule_radius = 12;
          capsule_opacity = 1.0;
          # Left pills — launcher + workspaces
          start = [
            "launcher"
            "workspaces"
          ];
          center = [ "clock" ];
          end = [
            "network"
            "bluetooth"
            "volume"
            "battery"
            "control-center"
            "session"
          ];
          # Per-pill Storm — wifi green, bluetooth red, etc. per theme/tokens.nix
          widgets.launcher.capsule_fill = "primary";
          widgets.workspaces.capsule_fill = "surface";
          widgets.clock.capsule_fill = "surface_variant";
          widgets.network.capsule_fill = "success";
          widgets.bluetooth.capsule_fill = "error";
          widgets.volume.capsule_fill = "info";
          widgets.battery.capsule_fill = "warning";
          widgets."control-center".capsule_fill = "secondary";
          widgets.session.capsule_fill = "error";
        };
      };

      # Theme — Tokyo Night Storm via custom palette (theme/noctalia-storm.json)
      theme = {
        mode = "dark";
        source = "custom";
        custom_palette = "Storm";
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

  xdg.configFile."noctalia/palettes/Storm.json".source = ../theme/noctalia-storm.json;
}
