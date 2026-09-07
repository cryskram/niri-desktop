# shared/go.nix — Go devenv fragment
{ pkgs, ... }:
{
  imports = [ ./common.nix ];
  languages.go.enable = true;
  packages = with pkgs; [
    go
    gopls
    delve
    golangci-lint
    gotools
  ];
  # Example services: postgres/redis when needed via `services.postgres.enable`
}
