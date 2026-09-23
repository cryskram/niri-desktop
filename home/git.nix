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
  ];
}
