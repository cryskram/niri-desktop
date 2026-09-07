# System shell — fish as login shell (RICE §20)
{ pkgs, ... }:
{
  programs.fish.enable = true;
  users.users.vageesh.shell = pkgs.fish;
  # Ensure fish is in /etc/shells
  environment.shells = with pkgs; [ fish ];
}
