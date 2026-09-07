{ pkgs, ... }:
{
  languages.go.enable = true;
  packages = with pkgs; [
    go
    gopls
    delve
    golangci-lint
    gotools
  ];
  # services.postgres.enable = true;
  # services.redis.enable = true;
}
