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
      add_newline = true;
      format = "$directory$git_branch$git_status$git_metrics$nix_shell$direnv$container$golang$nodejs$python$rust$java$line_break$character";
      character = {
        success_symbol = "[>](bold #cba6f7)";
        error_symbol = "[>](bold #f38ba8)";
        vicmd_symbol = "[>](bold #89b4fa)";
      };
      directory = {
        style = "bold #cba6f7";
        truncation_length = 3;
        truncate_to_repo = true;
      };
      git_branch = {
        style = "bold #89b4fa";
        format = "[\($branch\)](bold #89b4fa) ";
      };
      git_status = {
        style = "bold #f9e2af";
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        stashed = "\\$";
        ahead = "⇡$count ";
        behind = "⇣$count ";
        diverged = "⇕⇡$ahead_count⇣$behind_count ";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
        untracked = "?";
      };
      git_metrics = {
        disabled = false;
        added_style = "bold #a6e3a1";
        deleted_style = "bold #f38ba8";
        format = "([+$added]($added_style) )([-$deleted]($deleted_style) )";
      };
      nix_shell = {
        symbol = " ";
        style = "bold #89dceb";
        format = "[\($symbol$state\)](bold #89dceb) ";
        impure_msg = "impure";
        pure_msg = "pure";
      };
      direnv = {
        disabled = false;
        symbol = " ";
        style = "bold #fab387";
        format = "[\($symbol$loaded/$allowed\)](bold #fab387) ";
        loaded_msg = "loaded";
        unloaded_msg = "not loaded";
        allowed_msg = "allowed";
        not_allowed_msg = "not allowed";
      };
      container = {
        symbol = " ";
        style = "bold #a6e3a1";
        format = "[\($symbol $name\)](bold #a6e3a1) ";
      };
      cmd_duration = {
        min_time = 2000;
        format = "[took $duration](bold #f38ba8) ";
      };
      golang = {
        symbol = " ";
        style = "bold #89dceb";
        format = "[\($symbol$version\)](bold #89dceb) ";
      };
      nodejs = {
        symbol = " ";
        style = "bold #a6e3a1";
        format = "[\($symbol$version\)](bold #a6e3a1) ";
      };
      python = {
        symbol = " ";
        style = "bold #f9e2af";
        format = "[\($symbol$version\)](bold #f9e2af) ";
      };
      rust = {
        symbol = " ";
        style = "bold #f38ba8";
        format = "[\($symbol$version\)](bold #f38ba8) ";
      };
      java = {
        symbol = " ";
        style = "bold #fab387";
        format = "[\($symbol$version\)](bold #fab387) ";
      };
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
