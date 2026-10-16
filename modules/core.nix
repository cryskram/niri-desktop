# Core system configuration.
# Extracted from the inline module in flake.nix for clean architecture (RICE Phase 1).
# No behavior change — purely structural refactor.
{
  lib,
  pkgs,
  nixpkgs-unstable,
  spicetify-nix,
  ...
}:
let
  # Third-party pi extensions, pinned in pi/packages.nix. Hoisted so both the
  # extensions list and the skills list below can reference them.
  piPackages = import ../pi/packages.nix { inherit pkgs; };

  # pi-subagents excludes global context and skills by default. Opt every built-in
  # role into the same instructions, memory skill, and project context as the parent.
  sharedSubagentContext = {
    inheritProjectContext = true;
    inheritGlobalContext = true;
    inheritSkills = true;
  };
in
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

  # Coding-agent CLIs that live on nixpkgs-unstable, exposed through one imported
  # instance. `import` (not `.legacyPackages`) is deliberate: legacyPackages carries
  # nixpkgs' own default config, which refuses unfree packages — that broke evaluation
  # for claude-code (unfree) even though the system sets allowUnfree. `config =
  # prev.config` mirrors the system nixpkgs config (allowUnfree, …).
  nixpkgs.overlays = [
    (final: prev:
      let
        unstable = import nixpkgs-unstable {
          system = prev.stdenv.hostPlatform.system;
          config = prev.config;
        };
      in
      {
        opencode = unstable.opencode;
        pi-coding-agent = unstable.pi-coding-agent;

        # herdr — agent multiplexer / terminal workspace for coding agents.
        herdr = unstable.herdr;

        # claude-code — Anthropic's agentic coding CLI (unfree; releases far more
        # often than stable follows: 2.1.292 on unstable vs 2.1.223 in stable 26.05).
        # nixpkgs wraps its runtime deps (ripgrep, bubblewrap, socat); the former
        # claude-code-bin attribute was merged into it upstream.
        claude-code = unstable.claude-code;

        # DankMaterialShell — Wayland shell (bar/launcher/notifications/lock/wallpaper).
        # Stable 26.05 ships 1.4.x; 1.6.x adds the island bar layout. quickshell is
        # overlaid too because DMS 1.6 requires a current one.
        dms-shell = unstable.dms-shell;
        quickshell = unstable.quickshell;
      })
  ];

  programs.pi.coding-agent = {
    enable = true;
    package = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent;

    settings = {
      defaultProvider = "jev";
      defaultModel = "auto";
      defaultThinkingLevel = "high";
      theme = "catppuccin-macchiato";
      defaultTools = [ "+codemode" ]; # keep read/bash/edit/write + codemode (JS orchestration, parallel calls, image models)

      # Good development ergonomics — explicit declarative defaults (see pi docs: settings.md, sessions.md).
      enableSkillCommands = true;
      hideThinkingBlock = false;
      showCacheMissNotices = false;
      autocompleteMaxVisible = 7;
      terminal.showTerminalProgress = true;
      compaction = {
        enabled = true;
        reserveTokens = 16384;
        keepRecentTokens = 20000;
      };
      # Generic subagent defaults — works in any project (cwd).
      # All children use jev/auto (provider jev), same as main session — high thinking.
      # deepseek-v4-flash is deliberately NOT used: it emits tool calls as plain
      # DSML/XML text instead of structured calls (22 such leaks in one session;
      # deepseek-v4.1-flash leaks the same way), so a tool-driven child spends its
      # turn printing a call that pi then renders instead of executing — which is
      # exactly the "subagent takes forever" behaviour.
      subagents = {
        defaultModel = "auto";
        # Ensure researcher/evidence-auditor have web tools even as foreground children
        # (background children already inherit ambient extensions). Works for any cwd.
        defaultSubagentOnlyExtensions = [ "${piPackages.pi-web-access}" ];
        agentOverrides = {
          # Second-opinion oracle, reviews and research stay on jev/auto; only budgets differ.
          oracle = sharedSubagentContext // {
            model = "auto";
            thinking = "high";
          };
          reviewer = sharedSubagentContext // {
            model = "auto";
            thinking = "high";
          };
          researcher = sharedSubagentContext // {
            model = "auto";
            thinking = "high";
          };
          evidence-auditor = sharedSubagentContext;
          delegate = sharedSubagentContext;
          # Workers/scouts: high thinking as requested for jev auto.
          worker = sharedSubagentContext // {
            thinking = "high";
          };
          scout = sharedSubagentContext // {
            thinking = "high";
          };
        };
      };
    };

    # Repo-owned skills (tracked via the flake). The parent dir is passed (like
    # promptTemplates) so pi discovers pi/skills/<name>/SKILL.md and labels the
    # skill by its own folder name instead of the hashed store root. This includes
    # the shared learnings journal and the Vageesh skill scaffold. Company skills
    # stay outside the repo (~/Projects/TAP) and are wired via extraArgs strings
    # (bypasses flake path copy).
    #
    # pi-btw's bundled skill is listed explicitly: pi only reads a package's
    # skills manifest for npm:/git: sources, so passing the extension as a local
    # store path would load the extension but silently drop the skill.
    skills = [
      ../pi/skills
      "${piPackages.pi-btw}/skills/btw"
    ];

    # Compact global Pi bootstrap, appended to the built-in system prompt.
    # The layered cross-project contract is also linked as user-level AGENTS.md below.
    rules = ../pi/brain/APPEND_SYSTEM.md;

    # Prompt templates: intentionally empty — skills are the mechanism (see pi/skills/).
    # Keep `pi/prompts/.gitkeep` so the directory tracks; add real templates deliberately.
    promptTemplates = [ ];

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
        inherit (piPackages)
          pi-btw
          rpiv-ask-user-question
          rpiv-todo
          zentui
          pi-subagents
          pi-web-access
          ;
      in
      [
        # Third-party extensions, pinned in pi/packages.nix.
        "${pi-btw}"
        "${rpiv-ask-user-question}/${rpiv-ask-user-question.extensionPath}"
        "${rpiv-todo}/${rpiv-todo.extensionPath}"
        "${zentui}"
        "${pi-subagents}"
        "${pi-web-access}"
        ../pi/extensions/safety.ts
        ../pi/extensions/jev-router.ts
        # MCP panel (/mcpx) + live `mcp` status key for zentui's Extension statuses
        # (/zentui extensions): enabled servers as `● name(count)`, refreshed on
        # a 2s poll so a disabled server disappears without waiting for the next prompt.
        # Pass the directory (not index.ts): Nix copies a single file path alone
        # into the store, dropping the sibling panel.ts/state.ts imports. A
        # directory copies whole, and pi resolves <dir>/index.ts itself.
        ../pi/extensions/mcp-panel
        # Querion session archive — /sync uploads pi sessions for on-the-go reading.
        # Configured via xdg.configFile."querion/config.json" (home-manager block below).
        ../pi/extensions/querion-sync.ts
      ];
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = { inherit spicetify-nix; };

  home-manager.users.vageesh = {
    imports = [
      spicetify-nix.homeManagerModules.default
      ../home/niri.nix
      ../home/desktop.nix
      ../home/theme.nix
      ../home/ux.nix
      ../home/shell.nix
      ../home/files.nix
      ../home/scripts.nix
      ../home/git.nix
      ../home/direnv.nix
      ../home/development.nix
      ../home/applications.nix
      ../home/spicetify.nix
      ../home/neovim.nix
      ../home/zed.nix
      ../home/opencode-quota-fetch.nix
    ];

    home.stateVersion = "26.05";

    # Pi discovers this user-level context file across working directories.
    # Expose the whole canonical brain beside it for global/child-agent lookup;
    # never hand-edit these generated ~/.pi links.
    home.file.".pi/agent/AGENTS.md".source = ../pi/brain/AGENTS.md;
    home.file.".pi/agent/brain".source = ../pi/brain;

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

    # rpiv-todo overlay collapse shortcut (extension reads, never writes, this file).
    xdg.configFile."rpiv-todo/config.json".text = builtins.toJSON {
      collapseKey = "alt+t";
    };

    # MCP servers — native pi (0.99+) reads ~/.pi/agent/mcp.json directly.
    # pi-web-access already provides web_search/fetch/source_check, so the
    # parallel-search/deepwiki/chrome-devtools MCPs are redundant. The local
    # dummy harness that once lived here has been removed now that the MCP
    # wiring is understood; add servers as their own entries below.
    home.file.".pi/agent/mcp.json".text = builtins.toJSON {
      mcpServers = {
        # VeriDB — policy-controlled database MCP for AI agents (PostgreSQL).
        # Source: /home/vageesh/Projects/veridb. The binary is built with
        # `make build` over there; this entry just execs it, so rebuild the
        # binary after veridb updates. Credentials never land here: the server
        # reads them itself from its own .env via -env-file, and the local
        # config it points at (veridb.local.yaml) is gitignored upstream.
        veridb = {
          command = "/home/vageesh/Projects/veridb/bin/veridb";
          args = [
            "-config"
            "/home/vageesh/Projects/veridb/configs/veridb.local.yaml"
            "-env-file"
            "/home/vageesh/Projects/veridb/.env"
          ];
        };
      };
    };

    # One-time cleanup of the old adapter path. Home Manager leaves unmanaged
    # files in place, so without this ~/.config/mcp/mcp.json (and its .backup)
    # would linger as an orphan after the migration to ~/.pi/agent/mcp.json.
    home.activation.cleanupMcpAdapter = ''
      rm -f "$HOME/.config/mcp/mcp.json" "$HOME/.config/mcp/mcp.json.backup"
      rmdir --ignore-fail-on-non-empty "$HOME/.config/mcp" 2>/dev/null || true
    '';

    # One-time cleanup for the pi extensions removed on 2026-10-16. Their state is
    # regenerable and nothing owns it once the extension is gone: the FTS index
    # (11M) and the cache-optimizer's stat shards/config would otherwise linger.
    home.activation.cleanupRemovedPiExtensions = ''
      rm -rf "$HOME/.pi/session-search"
      rm -rf "$HOME/.pi/agent/pi-cache-optimizer-stats.d"
      rm -f "$HOME/.pi/agent/pi-cache-optimizer-config.json"
    '';

  };

  environment.sessionVariables = {
    # System-wide cursor Catppuccin Macchiato Mauve
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "catppuccin-macchiato-mauve-cursors";
    # Electron Wayland (Postman, Slack, Discord, Figma) — fixes Missing X server on Niri
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  # Services the DMS bar widgets need (bluetooth/battery pills vanished when
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
