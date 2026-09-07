# Zed — fast GPU editor (DEV_ENVIRONMENT Phase 3)
# fish + direnv + devenv friendly; Tokyo Night Storm via theme.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zed-editor
  ];

  # Zed settings are *not* managed here — user owns ~/.config/zed/settings.json
  # (so themes/extensions persist). Example defaults are in docs/zed-settings.json.example
  home.sessionVariables.EDITOR = "nvim"; # keep nvim as $EDITOR, zed as GUI
}
