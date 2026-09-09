# Desktop applications — Home Manager (DEV_ENVIRONMENT §8)
# Chrome/Ghostty/Nautilus/Yazi already in desktop/files; adding comms + design + IDEs.
# Check availability before packaging; prefer nixpkgs stable.
{ pkgs, ... }:
{
  # Fix Figma auth: figma-linux upstream desktop lacks MimeType, so figma:// -> browser
  # "No such app" fails. Override with correct handler + mime association.
  xdg.mimeApps = {
    associations.added."x-scheme-handler/figma" = "figma-linux.desktop";
    defaultApplications."x-scheme-handler/figma" = "figma-linux.desktop";
  };
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

    # database viewers
    beekeeper-studio
    jetbrains.datagrip
  ];
}
