# Spicetify — Spotify Tokyo Night Storm (DEV, RICE §4)
# Uses spicetify-nix (follows nixpkgs) for declarative theming.
{ pkgs, spicetify-nix, ... }:
let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{

  programs.spicetify = {
    enable = true;
    # Theme: text (clean, easy to recolor) + Storm palette
    theme = spicePkgs.themes.text;
    colorScheme = "custom";
    customColorScheme = {
      text = "c0caf5";
      subtext = "a9b1d6";
      sidebarText = "c0caf5";
      main = "24283b";
      sidebar = "1a1b26";
      player = "24283b";
      card = "2a2f4a";
      shadow = "1a1b26";
      selectedRow = "414868";
      button = "7aa2f7";
      buttonActive = "7aa2f7";
      buttonDisabled = "565f89";
      tabActive = "7aa2f7";
      notification = "7aa2f7";
      notificationError = "f7768e";
      misc = "565f89";
    };
    enabledExtensions = with spicePkgs.extensions; [
      shuffle
      # add more: adblock, hidePodcasts, etc. as needed
    ];
    # Keep Spotify features like local files disabled for simplicity
  };
}
