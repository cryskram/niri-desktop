# shared/python.nix — Python devenv fragment (uv preferred)
{ pkgs, ... }:
{
  imports = [ ./common.nix ];
  languages.python = {
    enable = true;
    package = pkgs.python3;
    uv.enable = true;
  };
  packages = with pkgs; [
    ruff
    black
    mypy
    pyright
  ];
}
