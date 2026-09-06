# System shell — ensure zsh is available as login shell (RICE §20)
{ pkgs, ... }:
{
  programs.zsh.enable = true;
  users.users.vageesh.shell = pkgs.zsh;
}
