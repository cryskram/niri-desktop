# Core system configuration.
# Extracted from the inline module in flake.nix for clean architecture (RICE Phase 1).
# No behavior change — purely structural refactor.
{
  lib,
  pkgs,
  noctalia,
  nixpkgs-unstable,
  spicetify-nix,
  ...
}:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Allow the flake's `nixConfig` (extra caches) without prompting for
    # `nixos-rebuild --accept-flake-config` on every switch.
    accept-flake-config = true;
    trusted-users = [
      "root"
      "vageesh"
    ];

    extra-substituters = [
      "https://pi.cachix.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nixpkgs.overlays = [
    (final: prev: {
      opencode = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.opencode;

      pi-coding-agent =
        nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.pi-coding-agent;

      # herdr — agent multiplexer / terminal workspace for coding agents.
      # Only in nixpkgs-unstable so far, exposed via the overlay like pi/opencode.
      herdr = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.herdr;
    })
  ];

  programs.pi.coding-agent = {
    enable = true;
    package = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent;

    settings = {
      defaultProvider = "opencode-go";
      defaultModel = "muse-spark-1.2-contributor";
      defaultThinkingLevel = "medium";
      theme = "catppuccin-macchiato";
    };

    # Repo-owned skills (tracked via the flake). The parent dir is passed (like
    # promptTemplates) so pi discovers pi/skills/<name>/SKILL.md and labels the
    # skill by its own folder name instead of the hashed store root. Company
    # skills stay outside the repo (~/Projects/TAP) and are wired via extraArgs
    # strings (bypasses flake path copy).
    skills = [
      ../pi/skills
    ];

    # Global operating rules appended to pi's system prompt (safety, secrets,
    # declarative-repo awareness). Enforced at the tool level by the extension below.
    rules = ../pi/rules.md;

    promptTemplates = [
      ../pi/prompts
    ];

    themes = [
      ../pi/themes/catppuccin-macchiato.json
    ];

    extraArgs = [
      "--skill"
      "/home/vageesh/Projects/TAP/claude-plugins/engineering/skills/backend/backend-coding-practices"
      "--skill"
      "/home/vageesh/Projects/TAP/claude-plugins/engineering/skills/qa/backend-to-qa"
      "--skill"
      "/home/vageesh/Projects/TAP/claude-plugins/engineering/skills/qa/web-to-qa"
      "--skill"
      "/home/vageesh/Projects/TAP/claude-plugins/engineering/skills/qa/mobile-to-qa"
      "--skill"
      "/home/vageesh/Projects/TAP/claude-plugins/engineering/skills/qa/generate-test-cases"
      "--skill"
      "/home/vageesh/Projects/TAP/claude-plugins/engineering/skills/qa/qa-signoff"
      "--skill"
      "/home/vageesh/Projects/TAP/claude-plugins/ultra-mariadb/skills/schema-reference"
      "--skill"
      "/home/vageesh/Projects/TAP/claude-plugins/ultra-mariadb/skills/query-patterns"
    ];

    extensions =
      let
        inherit (import ../pi/packages.nix { inherit pkgs; })
          mcp-adapter
          rpiv-ask-user-question
          rpiv-todo
          zentui
          ;
      in
      [
        # Third-party extensions, pinned in pi/packages.nix.
        "${mcp-adapter}"
        "${rpiv-ask-user-question}/${rpiv-ask-user-question.extensionPath}"
        "${rpiv-todo}/${rpiv-todo.extensionPath}"
        "${zentui}"
        ../pi/extensions/safety.ts
        # Querion session archive — /sync uploads pi sessions for on-the-go reading.
        # Configured via xdg.configFile."querion/config.json" (home-manager block below).
        ../pi/extensions/querion-sync.ts
      ];
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = { inherit noctalia spicetify-nix; };

  home-manager.users.vageesh = {
    imports = [
      spicetify-nix.homeManagerModules.default
      ../home/niri.nix
      ../home/desktop.nix
      ../home/theme.nix
      ../home/ux.nix
      ../home/shell.nix
      ../home/files.nix
      ../home/noctalia.nix
      ../home/scripts.nix
      ../home/git.nix
      ../home/direnv.nix
      ../home/development.nix
      ../home/applications.nix
      ../home/spicetify.nix
      ../home/neovim.nix
      ../home/zed.nix
    ];

    home.stateVersion = "26.05";

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
    };

    # Querion (pi /sync). Written as a config file the extension reads directly,
    # so it does not depend on session environment variables reaching the
    # Niri/Ghostty/fish session. The token stays in a gitignored file.
    xdg.configFile."querion/config.json".text = builtins.toJSON {
      url = "https://querion-plum.vercel.app";
      tokenFile = "/home/vageesh/niri-desktop/secrets/querion-token";
    };

    # MCP servers for the pi-mcp-adapter extension. Previously an imperative
    # ~/.config/mcp/mcp.json; the adapter reads this path as its "shared-global
    # standard MCP" source. No secrets here.
    #
    # parallel-search uses /mcp-oauth, not /mcp: /mcp serves anonymous traffic
    # and publishes no OAuth metadata (/.well-known/oauth-protected-resource
    # returns 404), so Dynamic Client Registration fails there with
    # "HTTP 404: Not found". /mcp-oauth returns 401 anonymously and advertises
    # the metadata document, so OAuth sign-in works.
    # deepwiki is a public service with no auth and no OAuth metadata, so it is
    # left anonymous and must not be authenticated.
    xdg.configFile."mcp/mcp.json".text = builtins.toJSON {
      mcpServers = {
        chrome-devtools = {
          command = "npx";
          args = [
            "-y"
            "chrome-devtools-mcp@1.6.0"
          ];
        };
        parallel-search = {
          url = "https://search.parallel.ai/mcp-oauth";
          protocolVersion = "auto";
          directTools = true;
        };
        deepwiki = {
          url = "https://mcp.deepwiki.com/mcp";
          protocolVersion = "auto";
        };
      };
    };
  };

  environment.sessionVariables = {
    # System-wide cursor Catppuccin Macchiato Mauve
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "catppuccin-macchiato-mauve-cursors";
    # Electron Wayland (Postman, Slack, Discord, Figma) — fixes Missing X server on Niri
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  # Services the Noctalia bar widgets need (bluetooth/battery pills vanished when
  # GNOME desktop was removed — these were implicitly enabled by it).
  hardware.bluetooth.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = with pkgs; [
    opencode
    awscli2
    jq
    jdk17
    jdk # latest (21) — for projects needing latest, use JAVA_HOME=${pkgs.jdk}/lib/openjdk or devenv override
    glow
  ];
}
