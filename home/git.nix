# Git — declarative, preserves existing ~/.gitconfig (cryskram)
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
    gitCredentialHelper.enable = true;
  };

  home.packages = with pkgs; [
    git-lfs
  ];
}
