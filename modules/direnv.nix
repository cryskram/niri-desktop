# direnv + nix-direnv + devenv — global activation (DEV_ENVIRONMENT §10, §11)
# Makes `devenv init; direnv allow` work and project .envrc auto-activate.
{ pkgs, ... }:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # Optional: silent + faster
    # settings = { global.warn_timeout = "30s"; };
  };

  environment.systemPackages = with pkgs; [
    devenv
  ];
}
