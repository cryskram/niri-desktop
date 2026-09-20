# Spicetify — Spotify Catppuccin Macchiato (DEV, RICE §4)
# Uses spicetify-nix (follows nixpkgs) for declarative theming.
{ pkgs, spicetify-nix, ... }:
let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{

  programs.spicetify = {
    enable = true;
    # Theme: text + Catppuccin Macchiato palette
    theme = spicePkgs.themes.text;
    colorScheme = "custom";
    customColorScheme = {
      text = "cad3f5";
      subtext = "b8c0e0";
      sidebarText = "cad3f5";
      main = "24273a";
      sidebar = "1e2030";
      player = "24273a";
      card = "363a4f";
      shadow = "181926";
      selectedRow = "494d64";
      button = "c6a0f6";
      buttonActive = "c6a0f6";
      buttonDisabled = "5b6078";
      tabActive = "c6a0f6";
      notification = "c6a0f6";
      notificationError = "ed8796";
      misc = "5b6078";
    };
    enabledExtensions = with spicePkgs.extensions; [
      shuffle
      # add more: adblock, hidePodcasts, etc. as needed
    ];
    # Keep Spotify features like local files disabled for simplicity
  };
}
