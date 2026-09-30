# Git — declarative; the repo is the only source of git config.
# RICE §31 + DEV_ENVIRONMENT §9: reproducible Git + GitHub CLI
{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "cryskram";
      user.email = "vageeshgn2005@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
      # delta renders diffs in Catppuccin Macchiato (syntax-theme below).
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        line-numbers = true;
        navigate = true;
        # Delta hands the name to bat, which matches the exact display name
        # ("Catppuccin Macchiato"); the kebab form makes bat fall back with
        # "[bat warning]: Unknown theme 'catppuccin-macchiato'" and deltas
        # render uncolored.
        syntax-theme = "Catppuccin Macchiato";
        # Keep paging inside terminal apps (pi, tmux-like panes, herdr).
        paging = "never";
      };
      pager = {
        diff = "delta";
        log = "delta";
        reflog = "delta";
        show = "delta";
        blame = "delta";
      };
      merge.conflictstyle = "zdiff3";
      alias = {
        st = "status -sb";
        co = "checkout";
        br = "branch";
        lg = "log --oneline --graph --decorate --all";
        last = "log -1 --stat";
        unstage = "restore --staged";
      };
      diff.colorMoved = "default";
      push.autoSetupRemote = true;
    };
  };

  programs.gh = {
    enable = true;
    # The credential helper is set explicitly below rather than through
    # gitCredentialHelper, which pins "${pkgs.gh}/bin/gh". A store path goes
    # stale as soon as gh is updated and the old path is collected, and git then
    # fails every fetch with "No such file or directory" — which is exactly what
    # happened with gh-2.99.0. "!gh ..." resolves gh from PATH, so it always
    # follows the current package.
    gitCredentialHelper.enable = false;

    # Home Manager owns ~/.config/gh/config.yml as a read-only store symlink, so
    # `gh config set` cannot write to it and prints
    # "open ~/.config/gh/config.yml: read-only file system". Set gh options here
    # instead. https is also the module default; stating it explicitly so the
    # read-only conflict reads as intentional rather than a surprise.
    settings.git_protocol = "https";
  };

  programs.git.settings.credential = {
    # The leading "" clears any inherited helper list, so a stale entry from
    # another gitconfig cannot survive and get used first.
    "https://github.com".helper = [
      ""
      "!gh auth git-credential"
    ];
    "https://gist.github.com".helper = [
      ""
      "!gh auth git-credential"
    ];
  };

  home.packages = with pkgs; [
    git-lfs
    # Diff/merge pager — colored Macchiato diffs (wired via core.pager above).
    delta
  ];
}
