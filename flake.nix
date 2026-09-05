{
  description = "Declarative NixOS with latest pi + opencode";

  nixConfig = {
    extra-substituters = [
      "https://pi.cachix.org"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    pi.url = "github:lukasl-dev/pi.nix";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, pi, home-manager, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit pi; };

      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        pi.nixosModules.default
        home-manager.nixosModules.home-manager

        ({ pkgs, ... }: {
          nix.settings = {
            experimental-features = [
              "nix-command"
              "flakes"
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
              opencode =
                nixpkgs-unstable.legacyPackages.${prev.system}.opencode;

              pi-coding-agent =
                nixpkgs-unstable.legacyPackages.${prev.system}.pi-coding-agent;
            })
          ];

          programs.pi.coding-agent = {
            enable = true;
            package =
              nixpkgs-unstable.legacyPackages.${pkgs.system}.pi-coding-agent;

            settings = {
              defaultProvider = "opencode-go";
              defaultModel = "kimi-k2.6";
              defaultThinkingLevel = "medium";
            };
          };

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.vageesh = {
            home.stateVersion = "26.05";

            xdg.configFile."opencode/opencode.json".text =
              builtins.toJSON {
                "$schema" = "https://opencode.ai/config.json";
              };
          };

          environment.systemPackages = with pkgs; [
            opencode
          ];
        })
      ];
    };
  };
}
