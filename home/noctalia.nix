# Noctalia — crazy beautiful r/unixporn shell, Catppuccin Macchiato
# Glass, blur, capsule bar, Niri workspaces, Macchiato palette
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

      # Glass backdrop with blur — mission-control vibe (more blur)
      backdrop = {
        enabled = true;
        blur_intensity = 0.85;
        tint_intensity = 0.25;
      };

      # Bar — TRUE ISLANDS: Macchiato glass (more transparent)
      # Sidebar-ready: position top (horizontal) now, change to "left" for vertical sidebar.
      # For sidebar: thickness = width, start=top center=middle end=bottom, clock vertical_format used.
      bar = {
        order = [ "main" ];
        default.enabled = false;
        main = {
          position = "top";
          thickness = 38;
          background_opacity = 0.62;
          radius = 12;
          margin_ends = 14;
          margin_edge = 8;
          padding = 6;
          widget_spacing = 8;
          shadow = false;
          reserve_space = true;
          border_width = 0.0;
          scale = 1.0;
          font_scale = 1.0;
          capsule = true;
          capsule_radius = 12;
          capsule_opacity = 0.88;
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

      # Per-pill Macchiato colors — Catppuccin pastels on mantle/base
      widget = {
        launcher = {
          capsule_fill = "#c6a0f6"; # mauve
          capsule_foreground = "#24273a";
        };
        workspaces = {
          capsule_fill = "#363a4f"; # surface0
          capsule_foreground = "#cad3f5";
          capsule_padding = 16;
        };
        clock = {
          capsule_fill = "#363a4f";
          capsule_foreground = "#cad3f5";
          format = "{:%a %d %b  %H:%M}";
          vertical_format = "{:%H:%M\n%a %d}";
          tooltip_format = "{:%A, %d %B %Y %H:%M}";
        };
        taskbar = {
          capsule_fill = "#363a4f";
          capsule_foreground = "#cad3f5";
        };
        media = {
          capsule_fill = "#f5a97f"; # peach
          capsule_foreground = "#24273a";
        };
        sysmon = {
          capsule_fill = "#363a4f";
          capsule_foreground = "#cad3f5";
        };
        notifications = {
          capsule_fill = "#363a4f";
          capsule_foreground = "#cad3f5";
        };
        network = {
          capsule_fill = "#a6da95"; # green
          capsule_foreground = "#24273a";
        };
        tray = {
          capsule_fill = "#363a4f";
          capsule_foreground = "#cad3f5";
          hide_passive = false;
          drawer = true;
          drawer_columns = 3;
        };
        bluetooth = {
          capsule_fill = "#ed8796"; # red
          capsule_foreground = "#24273a";
        };
        volume = {
          capsule_fill = "#91d7e3"; # sky
          capsule_foreground = "#24273a";
        };
        battery = {
          capsule_fill = "#eed49f"; # yellow
          capsule_foreground = "#24273a";
        };
        "control-center" = {
          capsule_fill = "#c6a0f6";
          capsule_foreground = "#24273a";
        };
        session = {
          capsule_fill = "#ed8796";
          capsule_foreground = "#24273a";
        };
      };

      # Theme — Catppuccin Macchiato via custom palette (theme/noctalia-macchiato.json)
      theme = {
        mode = "dark";
        source = "custom";
        custom_palette = "Macchiato";
        pure_black_dark = false;
      };

      # Notifications — glass toasts (more transparent)
      notification = {
        enable_daemon = true;
        show_app_name = true;
        background_opacity = 0.72;
        scale = 1.0;
      };

      # Lock screen (RICE §17) — elaborate: more blur + Macchiato tint
      lockscreen = {
        enabled = true;
        blurred_desktop = true;
        blur_intensity = 0.85;
        tint_intensity = 0.35;
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

  xdg.configFile."noctalia/palettes/Macchiato.json".source = ../theme/noctalia-macchiato.json;
}
