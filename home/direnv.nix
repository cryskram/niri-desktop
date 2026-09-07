# direnv — Home Manager side (zsh integration, nix-direnv)
# System side is in modules/direnv.nix; this ensures shell integration for vageesh.
{ ... }:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
