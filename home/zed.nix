# Zed — fast GPU editor (DEV_ENVIRONMENT Phase 3)
# fish + direnv + devenv friendly; Tokyo Night Storm via theme.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zed-editor
  ];

  # Zed settings — Storm, JetBrains Mono, fish as terminal
  xdg.configFile."zed/settings.json".text = builtins.toJSON {
    theme = {
      mode = "dark";
      dark = "Tokyo Night Storm";
      light = "Tokyo Night Storm";
    };
    buffer_font_family = "JetBrains Mono";
    buffer_font_size = 13;
    ui_font_family = "Inter";
    ui_font_size = 14;
    terminal = {
      shell = {
        program = "fish";
      };
      font_family = "JetBrains Mono";
      font_size = 13;
    };
    vim_mode = false;
    telemetry = {
      diagnostics = false;
      metrics = false;
    };
    auto_update = false;
    # Keep Zed light — LSP via languages (gopls, rust-analyzer, etc. already global)
  };

  # Ensure zed respects wayland
  home.sessionVariables.EDITOR = "nvim"; # keep nvim as $EDITOR, zed as GUI
}
