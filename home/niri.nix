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
{
  xdg.configFile."niri/config.kdl".text = ''
    // Managed by ~/niri-desktop (home/niri.nix). Local edits will be overwritten.
    // The default config is included first so our overrides take precedence.
    include "${pkgs.niri.src}/resources/default-config.kdl"

    // --- Phase 1 foundation overrides ---

    // Predictable screenshot location.
    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
  '';
}
