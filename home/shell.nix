# Shell — zsh + Starship + modern CLI (RICE §20)
# Fast startup, Wayland-friendly, Tokyo Night Storm via Starship palette
{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history.size = 10000;
    shellAliases = {
      ls = "eza --icons";
      ll = "eza -l --icons --git";
      la = "eza -la --icons --git";
      cat = "bat";
      grep = "rg";
      find = "fd";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = "$directory$git_branch$git_status$cmd_duration$character";
      character = {
        success_symbol = "[❯](bold #7aa2f7)";
        error_symbol = "[❯](bold #f7768e)";
      };
      directory.style = "bold #7aa2f7";
      git_branch.style = "bold #bb9af7";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza.enable = true;
  programs.bat.enable = true;
  programs.fd.enable = true;
  programs.ripgrep.enable = true;
  programs.jq.enable = true;
  programs.lazygit.enable = true;

  home.packages = with pkgs; [
    yq-go
  ];

  # Ensure zsh is the login shell (NixOS side sets users.users.vageesh.shell)
}
