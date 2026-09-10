# Spicetify — Spotify Catppuccin Mocha (DEV, RICE §4)
# Uses spicetify-nix (follows nixpkgs) for declarative theming.
{ pkgs, spicetify-nix, ... }:
let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{

  programs.spicetify = {
    enable = true;
    # Theme: text + Catppuccin Mocha palette
    theme = spicePkgs.themes.text;
    colorScheme = "custom";
    customColorScheme = {
      text = "cdd6f4";
      subtext = "bac2de";
      sidebarText = "cdd6f4";
      main = "1e1e2e";
      sidebar = "181825";
      player = "1e1e2e";
      card = "313244";
      shadow = "11111b";
      selectedRow = "45475a";
      button = "cba6f7";
      buttonActive = "cba6f7";
      buttonDisabled = "585b70";
      tabActive = "cba6f7";
      notification = "cba6f7";
      notificationError = "f38ba8";
      misc = "585b70";
    };
    enabledExtensions = with spicePkgs.extensions; [
      shuffle
      # add more: adblock, hidePodcasts, etc. as needed
    ];
    # Keep Spotify features like local files disabled for simplicity
  };
}
