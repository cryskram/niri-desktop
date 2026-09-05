# Niri user configuration (Home Manager).
#
# Phase 1 (Niri foundation): ship niri's stock default config (complete,
# sane keybinds) plus a few foundation-level overrides below.
#
# Note: Home Manager release-26.05 does not yet ship a
# `wayland.windowManager.niri` module, so the config file is written
# directly. It is validated at build time by the `niri-config-validate`
# flake check (`nix flake check`).
{
  pkgs,
  ...
}:
let
  tokens = import ../theme/tokens.nix;
in
{
  xdg.configFile."niri/config.kdl".text = ''
    // Managed by ~/niri-desktop (home/niri.nix). Local edits will be overwritten.
    // The default config is included first so our overrides take precedence.
    include "${pkgs.niri.src}/resources/default-config.kdl"

    // Prefer Niri-drawn decorations over client-side (removes GTK header-bar borders).
    prefer-no-csd

    // --- Phase 3 skeleton overrides ---

    // Wallpaper fallback (Tokyo Night Storm background — solid color, per RICE §18).
    // Decorative only; functionality must not depend on it.
    spawn-at-startup "swaybg" "-c" "${tokens.colors.background}"

    // Rings for every window — active vs inactive distinct (so you always know focus).
    // Border is always visible; focus-ring disabled to avoid double ring.
    layout {
        focus-ring {
            off
        }
        border {
            width 2
            active-color "${tokens.colors.accent-primary}"
            inactive-color "${tokens.colors.border}"
            urgent-color "${tokens.colors.error}"
        }
    }

    // Terminal — alacritty (primary per user preference, RICE §19).
    binds {
        "Mod+T" { spawn "alacritty"; }
    }

    // Predictable screenshot location.
    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
  '';
}
