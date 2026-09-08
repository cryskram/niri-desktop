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
          transparency_mode = "soft";
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
      # Sidebar-ready: position top (horizontal) now, change to "left" for vertical sidebar.
      # For sidebar: thickness = width, start=top center=middle end=bottom, clock vertical_format used.
      bar = {
        order = [ "main" ];
        default.enabled = false;
        main = {
          position = "top"; # "left" for sidebar (vertical)
          thickness = 38; # 48-56 for sidebar width
          background_opacity = 0.88;
          radius = 12;
          margin_ends = 14;
          margin_edge = 8;
          padding = 6;
          widget_spacing = 8;
          shadow = true;
          reserve_space = true;
          border_width = 0.0;
          scale = 1.0;
          font_scale = 1.0;
          capsule = true;
          capsule_radius = 12;
          capsule_opacity = 1.0;
          capsule_thickness = 0.8;
          capsule_padding = 12;
          # Horizontal top: start=left center middle end=right
          # Vertical left: start=top center=middle end=bottom (same arrays)
          start = [
            "launcher"
            "workspaces"
          ];
          center = [
            "clock"
            "taskbar"
            "media"
          ];
          end = [
            "tray"
            "sysmon"
            "notifications"
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
          capsule_padding = 16;
        };
        # Center — clock (date+time same capsule, sidebar vertical format)
        clock = {
          capsule_fill = "#292e42";
          capsule_foreground = "#c0caf5";
          format = "{:%a %d %b  %H:%M}";
          vertical_format = "{:%H:%M\n%a %d}";
          tooltip_format = "{:%A, %d %B %Y %H:%M}";
        };
        taskbar = {
          capsule_fill = "#414868";
          capsule_foreground = "#c0caf5";
        };
        media = {
          capsule_fill = "#bb9af7";
          capsule_foreground = "#1a1b26";
        };
        sysmon = {
          capsule_fill = "#414868";
          capsule_foreground = "#c0caf5";
        };
        notifications = {
          capsule_fill = "#414868";
          capsule_foreground = "#c0caf5";
        };
        # Right — system
        network = {
          capsule_fill = "#9ece6a";
          capsule_foreground = "#1a1b26";
        };
        tray = {
          capsule_fill = "#414868";
          capsule_foreground = "#c0caf5";
          hide_passive = false;
          drawer = false;
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

      # Lock screen (RICE §17) — elaborate: blurred desktop + Storm tint + big clock
      lockscreen = {
        enabled = true;
        blurred_desktop = true; # requires wlr-screencopy (falls back to solid)
        blur_intensity = 0.6;
        tint_intensity = 0.3;
      };

      lockscreen_widgets = {
        enabled = true;
        widget_order = [ "clock_main" ];
      };
      lockscreen_widgets.widget.clock_main = {
        type = "clock";
        cx = 960.0; # 1920x1080 center — refine for multi-monitor later (RICE §28)
        cy = 440.0;
        scale = 3.0;
        settings.format = "{:%H:%M}";
      };

      # Dynamic wallpaper (RICE §18): fade transitions, random rotation, static fallback
      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        fill_color = "surface";
        transition = [ "fade" ];
        transition_duration = 1500;
        directory = "~/Pictures/Wallpapers";
        default.path = "";
        automation = {
          enabled = true;
          interval_seconds = 300;
          order = "random";
          recursive = true;
        };
      };
    };
  };

  programs.quickshell.enable = lib.mkForce false;
  programs.quickshell.systemd.enable = lib.mkForce false;

  xdg.configFile."noctalia/palettes/Storm.json".source = ../theme/noctalia-storm.json;
}
