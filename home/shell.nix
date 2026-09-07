# Shell — fish + Starship + modern CLI (RICE §20) — Tokyo Night Storm
# Fast, Wayland-friendly, awesome fish (no zsh). Completions + tide-like starship.
{ pkgs, ... }:
{
  programs.fish = {
    enable = true;
    # Interactive helpers: vi-mode off (emacs), fast completions
    shellAbbrs = {
      g = "git";
      gs = "git status -sb";
      gc = "git commit";
      gp = "git push";
      lg = "lazygit";
      y = "yazi";
      cat = "bat";
      ls = "eza --icons";
      ll = "eza -l --icons --git";
      la = "eza -la --icons --git";
      grep = "rg";
      find = "fd";
    };
    shellAliases = {
      # keep abbreviations + aliases compatible with fish
      cat = "bat";
      grep = "rg";
      find = "fd";
    };
    interactiveShellInit = ''
      set -g fish_greeting ""
      # Tokyo Night Storm palette for fish
      set -g fish_color_command 7aa2f7
      set -g fish_color_param c0caf5
      set -g fish_color_quote 9ece6a
      set -g fish_color_error f7768e
      # history
      set -g fish_history_max 10000
      # zoxide + fzf keybinds are handled by HM integrations below
      # ensure starship transients work
    '';
    plugins = [
      # bass not needed — direnv handles env via fish integration
    ];
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
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
    enableFishIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.eza.enable = true;
  programs.bat.enable = true;
  programs.fd.enable = true;
  programs.ripgrep.enable = true;
  programs.jq.enable = true;
  programs.lazygit.enable = true;

  home.packages = with pkgs; [
    yq-go
    fish
  ];
}
