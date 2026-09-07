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
      # Global scale 1 default (RICE §1: 100% scaling)
      accessibility = {
        ui_scale = 1.0;
      };

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
          background_color = "#000000"; # fully transparent fallback
          radius = 0;
          margin_ends = 12;
          margin_edge = 8;
          padding = 0;
          widget_spacing = 10;
          shadow = false;
          reserve_space = true;
          border_width = 0.0;
          scale = 1.0;
          font_scale = 1.0;
          capsule = true;
          capsule_radius = 12;
          capsule_opacity = 1.0;
          capsule_thickness = 0.8;
          capsule_padding = 12;
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
        };
      };

      # Per-pill Storm colors — TOP-LEVEL [widget.<name>] tables (valid Noctalia syntax),
      # fixed hex per theme/tokens.nix (success/info/warning are not palette roles, hex works).
      widget = {
        # Left — launcher + workspaces
        launcher = {
          capsule_fill = "#7aa2f7";
          capsule_foreground = "#1a1b26";
        };
        workspaces = {
          capsule_fill = "#414868";
          capsule_foreground = "#c0caf5";
        };
        # Center — clock
        clock = {
          capsule_fill = "#292e42";
          capsule_foreground = "#c0caf5";
        };
        # Right — system
        network = {
          capsule_fill = "#9ece6a";
          capsule_foreground = "#1a1b26";
        };
        bluetooth = {
          capsule_fill = "#f7768e";
          capsule_foreground = "#1a1b26";
        };
        volume = {
          capsule_fill = "#7dcfff";
          capsule_foreground = "#1a1b26";
        };
        battery = {
          capsule_fill = "#e0af68";
          capsule_foreground = "#1a1b26";
        };
        "control-center" = {
          capsule_fill = "#bb9af7";
          capsule_foreground = "#1a1b26";
        };
        session = {
          capsule_fill = "#f7768e";
          capsule_foreground = "#1a1b26";
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
