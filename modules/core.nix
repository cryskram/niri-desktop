# Core system configuration.
# Extracted from the inline module in flake.nix for clean architecture (RICE Phase 1).
# No behavior change — purely structural refactor.
{
  lib,
  pkgs,
  noctalia,
  nixpkgs-unstable,
  ...
}:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Allow the flake's `nixConfig` (extra caches) without prompting for
    # `nixos-rebuild --accept-flake-config` on every switch.
    accept-flake-config = true;
    trusted-users = [
      "root"
      "vageesh"
    ];

    extra-substituters = [
      "https://pi.cachix.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # ai-usagebar — not in nixpkgs; prebuilt release binary (Noctalia plugin dep).
  # Credentials live in ~/.config/ai-usagebar/config.toml (never committed).
  nixpkgs.overlays = [
    (final: prev: {
      ai-usagebar =
        let
          version = "1.12.0";
          src = final.fetchurl {
            url = "https://github.com/akitaonrails/ai-usagebar/releases/download/v${version}/ai-usagebar-linux-x86_64.tar.gz";
            sha256 = "617254ada35b5a41fdf5953e3ffbcf18a4b5be92f513dbcba70dc5f41745e379";
          };
        in
        final.stdenv.mkDerivation {
          pname = "ai-usagebar";
          inherit version src;
          sourceRoot = ".";
          installPhase = ''
            install -Dm755 ai-usagebar $out/bin/ai-usagebar
            install -Dm755 ai-usagebar-tui $out/bin/ai-usagebar-tui
          '';
        };

      opencode = nixpkgs-unstable.legacyPackages.${prev.system}.opencode;

      pi-coding-agent = nixpkgs-unstable.legacyPackages.${prev.system}.pi-coding-agent;
    })
  ];

  programs.pi.coding-agent = {
    enable = true;
    package = nixpkgs-unstable.legacyPackages.${pkgs.system}.pi-coding-agent;

    settings = {
      defaultProvider = "opencode-go";
      defaultModel = "kimi-k2.6";
      defaultThinkingLevel = "medium";
    };

    extensions =
      let
        pi-web-search = pkgs.fetchFromGitHub {
          owner = "ttttmr";
          repo = "pi-web-search";
          rev = "83ac115e87bce29cf4c93af329b94ce5c306eaa8";
          hash = "sha256-MgpL9tSmjDSyIgLhxR874DZHga4SfmcN8xRmdRItf1I=";
        };
      in
      [ "${pi-web-search}/src/index.ts" ];
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = { inherit noctalia; };

  home-manager.users.vageesh = {
    imports = [
      ../home/niri.nix
      ../home/desktop.nix
      ../home/theme.nix
      ../home/ux.nix
      ../home/shell.nix
      ../home/files.nix
      ../home/noctalia.nix
    ];

    home.stateVersion = "26.05";

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
    };
  };

  environment.sessionVariables = {
    # System-wide cursor (compositor + apps read at session start; needs relogin)
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "Bibata-Modern-Classic";
  };

  # Services the Noctalia bar widgets need (bluetooth/battery pills vanished when
  # GNOME desktop was removed — these were implicitly enabled by it).
  hardware.bluetooth.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = with pkgs; [
    opencode
    ai-usagebar
  ];
}
