# Shell — fish + Starship + modern CLI (RICE §20) — Catppuccin Macchiato
# Fast, Wayland-friendly, awesome fish. Macchiato mauve palette.
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
      # Catppuccin Macchiato palette for fish
      set -g fish_color_command c6a0f6
      set -g fish_color_param cad3f5
      set -g fish_color_quote a6da95
      set -g fish_color_error ed8796
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
        success_symbol = "[>](bold #c6a0f6)";
        error_symbol = "[>](bold #ed8796)";
        vicmd_symbol = "[>](bold #8aadf4)";
      };
      directory = {
        style = "bold #c6a0f6";
        truncation_length = 3;
        truncate_to_repo = true;
      };
      git_branch = {
        style = "bold #8aadf4";
        format = "[\($branch\)](bold #8aadf4) ";
      };
      git_status = {
        style = "bold #eed49f";
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
        added_style = "bold #a6da95";
        deleted_style = "bold #ed8796";
        format = "([+$added]($added_style) )([-$deleted]($deleted_style) )";
      };
      nix_shell = {
        symbol = " ";
        style = "bold #91d7e3";
        format = "[\($symbol$state\)](bold #91d7e3) ";
        impure_msg = "impure";
        pure_msg = "pure";
      };
      direnv = {
        disabled = false;
        symbol = " ";
        style = "bold #f5a97f";
        format = "[\($symbol$loaded/$allowed\)](bold #f5a97f) ";
        loaded_msg = "loaded";
        unloaded_msg = "not loaded";
        allowed_msg = "allowed";
        not_allowed_msg = "not allowed";
      };
      container = {
        symbol = " ";
        style = "bold #a6da95";
        format = "[\($symbol $name\)](bold #a6da95) ";
      };
      cmd_duration = {
        min_time = 2000;
        format = "[took $duration](bold #ed8796) ";
      };
      golang = {
        symbol = " ";
        style = "bold #91d7e3";
        format = "[\($symbol$version\)](bold #91d7e3) ";
      };
      nodejs = {
        symbol = " ";
        style = "bold #a6da95";
        format = "[\($symbol$version\)](bold #a6da95) ";
      };
      python = {
        symbol = " ";
        style = "bold #eed49f";
        format = "[\($symbol$version\)](bold #eed49f) ";
      };
      rust = {
        symbol = " ";
        style = "bold #ed8796";
        format = "[\($symbol$version\)](bold #ed8796) ";
      };
      java = {
        symbol = " ";
        style = "bold #f5a97f";
        format = "[\($symbol$version\)](bold #f5a97f) ";
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

  # ~/.local/bin first on PATH. `home.sessionPath` prepends, which is what
  # `~/.local/bin` conventionally expects, and Home Manager exports it through
  # hm-session-vars so fish picks it up too. (xdg.localBinInPath is the other
  # option, but it appends and needs xdg.enable, which is off here.)
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.packages = with pkgs; [
    yq-go
    fish
  ];
}
