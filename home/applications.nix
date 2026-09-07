# Desktop applications — Home Manager (DEV_ENVIRONMENT §8)
# Chrome/Ghostty/Nautilus/Yazi already in desktop/files; adding comms + design + IDEs.
# Check availability before packaging; prefer nixpkgs stable.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── Browsers / terminals / files (already elsewhere, kept here for completeness) ──
    google-chrome
    ghostty
    nautilus # also in home/files.nix, duplicate ok
    yazi # also in home/files.nix

    # ── Communication ──
    spotify
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
    jetbrains.clion # C/C++ complement (optional, useful with clang-tools)
  ];
}
