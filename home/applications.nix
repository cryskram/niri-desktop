# Desktop applications — Home Manager (DEV_ENVIRONMENT §8)
# Chrome/Ghostty/Nautilus/Yazi already in desktop/files; adding comms + design + IDEs.
# Check availability before packaging; prefer nixpkgs stable.
{ pkgs, ... }:
{
  # Fix Figma auth: figma-linux upstream desktop lacks MimeType, so figma:// -> browser
  # "No such app" fails. Override with correct handler + mime association.
  xdg.mimeApps = {
    associations.added = {
      "x-scheme-handler/figma" = "figma-linux.desktop";
      "application/pdf" = [
        "sioyek.desktop"
        "org.pwmt.zathura-pdf-mupdf.desktop"
        "org.gnome.Evince.desktop"
      ];
    };
    defaultApplications = {
      "x-scheme-handler/figma" = "figma-linux.desktop";
      "application/pdf" = "sioyek.desktop";
    };
  };
  # ── Sioyek — Catppuccin Macchiato ─────────────────────────────────
  # Prefs are layered: /etc/prefs.config (defaults) + prefs_user.config (overrides)
  xdg.configFile."sioyek/prefs_user.config".text = ''
    # Catppuccin Macchiato — Niri Desktop (sioyek 2.0)
    # All colors 0-1 float. See https://sioyek-documentation.readthedocs.io

    # — base —
    background_color              0.141 0.153 0.227
    dark_mode_background_color    0.141 0.153 0.227
    dark_mode_contrast            0.88
    custom_background_color       0.141 0.153 0.227
    custom_text_color             0.792 0.827 0.961

    # — selection / search / links —
    text_highlight_color          0.776 0.627 0.965
    search_highlight_color        0.933 0.831 0.624
    link_highlight_color          0.541 0.678 0.957
    synctex_highlight_color       0.961 0.741 0.902
    visual_mark_color             0.776 0.627 0.965 0.22

    # — chrome —
    status_bar_color              0.118 0.125 0.188
    status_bar_text_color         0.792 0.827 0.961
    status_bar_font_size          13
    ui_font                       Inter
    font_size                     14
    page_separator_color          0.212 0.227 0.310
    page_separator_width          1
    ruler_mode                    1
    ruler_padding                 1.0
    ruler_x_padding               5.0

    # — behaviour —
    startup_commands              toggle_dark_mode
    zoom_inc_factor               1.15
    vertical_move_amount          1.0
    horizontal_move_amount        1.0
    move_screen_ratio             0.55
    fit_to_page_width_ratio       0.92
    create_table_of_contents_if_not_exists 1
    sort_bookmarks_by_location    1
    collapsed_toc                 0
    flat_toc                      0
    should_warn_about_user_key_override 1

    # — Catppuccin highlight palette (a-z) — muted pastels on Macchiato base
    highlight_color_a   0.776 0.627 0.965  # mauve
    highlight_color_b   0.541 0.678 0.957  # blue
    highlight_color_c   0.961 0.663 0.498  # peach
    highlight_color_d   0.961 0.741 0.902  # pink
    highlight_color_e   0.286 0.302 0.392  # surface1
    highlight_color_f   0.651 0.855 0.584  # green
    highlight_color_g   0.545 0.835 0.792  # teal
    highlight_color_h   0.933 0.831 0.624  # yellow
    highlight_color_i   0.569 0.843 0.890  # sky
    highlight_color_j   0.718 0.741 0.973  # lavender
    highlight_color_k   0.929 0.529 0.588  # red
    highlight_color_l   0.957 0.859 0.839  # rosewater
    highlight_color_m   0.776 0.627 0.965
    highlight_color_n   0.541 0.678 0.957
    highlight_color_o   0.961 0.663 0.498
    highlight_color_p   0.961 0.741 0.902
    highlight_color_q   0.651 0.855 0.584
    highlight_color_r   0.929 0.529 0.588
    highlight_color_s   0.933 0.831 0.624
    highlight_color_t   0.545 0.835 0.792
    highlight_color_u   0.718 0.741 0.973
    highlight_color_v   0.569 0.843 0.890
    highlight_color_w   0.776 0.627 0.965
    highlight_color_x   0.961 0.741 0.902
    highlight_color_y   0.933 0.831 0.624
    highlight_color_z   0.929 0.529 0.588
  '';

  xdg.configFile."sioyek/keys_user.config".text = ''
    # Sioyek keys_user — extras on top of defaults (see keys.config).
    # Keeps vim-like defaults, adds Niri-friendly aliases.
    # Format: <command> <key>  — multiple commands: cmd1;cmd2 <key>

    # — quick toggles —
    toggle_dark_mode        <C-d>
    toggle_custom_color     <C-S-d>
    toggle_highlight        <C-h>

    # — zoom / fit —
    fit_to_page_width       w
    fit_to_page_width_smart W
    zoom_in                 =
    zoom_in                 +
    zoom_out                -

    # — quality-of-life aliases —
    close_window            q
    toggle_fullscreen       <F11>
    goto_toc                T
    search                  <C-k>
  '';

  xdg.dataFile."applications/figma-linux.desktop".text = ''
    [Desktop Entry]
    Name=Figma Linux
    Comment=Unofficial Figma desktop application for Linux
    Exec=figma-linux %U
    Icon=figma-linux
    Terminal=false
    Type=Application
    Categories=Graphics;Design;
    MimeType=x-scheme-handler/figma;
    StartupWMClass=figma-linux
  '';

  home.packages = with pkgs; [
    # ── Browsers / terminals / files (already elsewhere, kept here for completeness) ──
    google-chrome
    ghostty
    nautilus # also in home/files.nix, duplicate ok
    yazi # also in home/files.nix
    obsidian # note taking

    # ── Communication ──
    # spotify via spicetify (home/spicetify.nix) — Catppuccin Macchiato
    slack
    discord

    # ── Design ──
    figma-linux
    # Bruno/Postman for API (DEV_ENVIRONMENT §7) — prefer Bruno lightweight
    bruno
    postman

    # ── JetBrains IDEs ──
    # IntelliJ IDEA Community discontinued → use unified `idea` (Ultimate trial + OSS via jetbrains.idea-oss)
    # Keep both goland and idea available; user can pick.
    jetbrains.goland
    jetbrains.idea

    # database viewers
    beekeeper-studio
    jetbrains.datagrip

    # ── Office ──
    libreoffice # stable 25.8.x (libreoffice-still alias) — Writer/Calc/Impress/Draw
    hunspell
    hunspellDicts.en_US
    hunspellDicts.en_GB-large

    # ── PDF — cool, Wayland-native, keyboard-first ──
    sioyek # GPU-accelerated, smart-jump, vim-like — main daily driver
    zathura # minimal tiling-native fallback (mupdf backend)
  ];
}
