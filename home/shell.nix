# Shell — fish + Starship + modern CLI (RICE §20) — Catppuccin Mocha
# Fast, Wayland-friendly, awesome fish. Mocha mauve palette.
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
      ls = "eza -la --icons --git";
      grep = "rg";
      find = "fd";
      zed = "zeditor";
    };
    shellAliases = {
      # keep abbreviations + aliases compatible with fish
      cat = "bat";
      grep = "rg";
      find = "fd";
    };
    interactiveShellInit = ''
      set -g fish_greeting ""
      # Catppuccin Mocha palette for fish
      set -g fish_color_command cba6f7
      set -g fish_color_param cdd6f4
      set -g fish_color_quote a6e3a1
      set -g fish_color_error f38ba8
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
        success_symbol = "[❯](bold #cba6f7)";
        error_symbol = "[❯](bold #f38ba8)";
      };
      directory.style = "bold #cba6f7";
      git_branch.style = "bold #89b4fa";
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
