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

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      pi,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;

      checks.${system} = {
        # Validate the generated niri config at build time (`nix flake check`).
        niri-config-validate =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            configFile =
              self.nixosConfigurations.nixos.config.home-manager.users.vageesh.xdg.configFile."niri/config.kdl";
          in
          pkgs.runCommand "niri-config-validate"
            {
              nativeBuildInputs = [ pkgs.niri ];
              inherit (configFile) source;
            }
            ''
              niri validate --config "$source"
              touch "$out"
            '';
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit pi nixpkgs-unstable;
        };

        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          ./modules/core.nix
          ./modules/theme.nix
          ./modules/shell.nix
          ./modules/niri.nix
          pi.nixosModules.default
          home-manager.nixosModules.home-manager
        ];
      };
    };
}
