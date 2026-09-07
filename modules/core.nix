# Core system configuration.
# Extracted from the inline module in flake.nix for clean architecture (RICE Phase 1).
# No behavior change — purely structural refactor.
{
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

  nixpkgs.overlays = [
    (final: prev: {
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

  # GNOME desktop forces ibus (mkDefault) → this overrides it: no ibus daemon,
  # no GTK/QT_IM_MODULE exports, no "Input Method: ibus" notification at login.
  i18n.inputMethod.type = lib.mkForce "none";

  environment.systemPackages = with pkgs; [
    opencode
  ];
}
