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

      # pi-guard — permission gate for tool calls.
      #
      # pi-guard resolves rules by EXACT tool name, and a tool with no entry falls
      # through to "ask" — which in a headless run (subagents, `pi -p`) means
      # *blocked*, not prompted. So this rule set is deliberately complete:
      # destructive operations are gated, and every other tool the agent can call
      # is listed as an outright allow. Adding an extension or an MCP server means
      # adding its tools here (`/guard list` shows what is in effect, and the
      # prompt UI offers to save a permanent allow).
      #
      # Two levels: `deny` blocks with no prompt (nothing denied is ever the right
      # answer to a request), `ask` confirms first — with an "allow for this
      # session" option, so a repeat costs one prompt rather than one per call.
      #
      # Rule order matters: `settings` is serialised sorted, so the catch-all "*"
      # sorts first and every specific rule after it. pi-guard takes the last
      # match, which is what makes a catch-all-first policy work.
      guard =
        let
          # For path-matched tools the catch-all is "**", NOT "*": a single `*`
          # does not cross "/", so with `*` every real path would fall through to
          # the "ask" default (verified: a write to an absolute path was blocked).
          protectedPaths = {
            "**" = "allow";
            "**/.ssh/**" = "deny";
            "**/.gnupg/**" = "deny";
            "**/.aws/**" = "deny";
            "**/secrets/**" = "deny";
            "**/.env" = "deny";
            "**/*.env" = "deny";
            "**/*.env.*" = "deny"; # .env.local and friends; .envrc stays writable
            "**/*.pem" = "deny";
            "**/*.key" = "deny";
            "**/id_*" = "deny";
            "**/.pi/agent/auth.json" = "deny";
          };
        in
        {
          enabled = true;
          rules = {
            bash = {
              # Ordinary commands run unprompted; everything below is the exception.
              "*" = "allow";

              # Hard stops: silent block, reason shown to the model.
              #
              # pi-guard requires a rule's FIRST token to equal the command name
              # exactly and treats only the remaining tokens as globs, so a
              # keyword-only rule such as "*DROP TABLE*" can never match. Database
              # clients are therefore named individually, with the keyword as a
              # glob against any argument.
              # (verified: without the client name, `sqlite3 … 'DROP TABLE t'` ran)
              # `dd` is denied outright rather than just its `of=` form: the value is
              # a path, and no reliable glob expresses it — a single `*` will not cross
              # "/", and `**` only acts as a globstar as a whole path segment
              # (verified: `of=*` and `of=**` both let `dd … of=/tmp/x` through).
              dd = "deny";
              mkfs = "deny";
              "mkfs.ext2" = "deny";
              "mkfs.ext3" = "deny";
              "mkfs.ext4" = "deny";
              "mkfs.xfs" = "deny";
              "mkfs.btrfs" = "deny";
              "mkfs.fat" = "deny";
              "mkfs.vfat" = "deny";
              dropdb = "deny";
              dropuser = "deny";
              "psql *DROP*" = "deny";
              "psql *TRUNCATE*" = "deny";
              "mariadb *DROP*" = "deny";
              "mysql *DROP*" = "deny";
              "sqlite3 *DROP*" = "deny";
              "redis-cli *FLUSH*" = "deny";

              # Confirm before running. `-r`/`-R`/`--recursive` are separate
              # spellings and `-fr` reverses the flags, so each form is listed;
              # pi-guard expands wrapper commands, which is why `sudo rm -rf`,
              # `bash -c 'rm -rf /'` and `find . -exec rm {} \;` all land here.
              "rm -r*" = "ask";
              "rm -R*" = "ask";
              "rm -fr*" = "ask";
              "rm -fR*" = "ask";
              "rm --recursive*" = "ask";
              "git reset --hard" = "ask";
              "git clean -f*" = "ask";
              "git push -f" = "ask";
              "git push --force" = "ask"; # --force-with-lease stays allowed
              "chmod 777*" = "ask";
              "docker system prune*" = "ask";
              "docker volume prune*" = "ask";
              "docker volume rm*" = "ask";
              "docker rm -f*" = "ask";
              "kubectl delete*" = "ask";
              "terraform destroy*" = "ask";
              "terraform apply -auto-approve*" = "ask";
              reboot = "ask";
              poweroff = "ask";
              halt = "ask";
              shutdown = "ask";
              "systemctl reboot" = "ask";
              "systemctl poweroff" = "ask";
              "systemctl halt" = "ask";
            };

            # File tools. Reads are unrestricted except private keys and .env
            # files; writes and edits respect protectedPaths.
            read = {
              "**" = "allow";
              "**/.env" = "deny";
              "**/*.env" = "deny";
              "**/*.env.*" = "deny";
              "**/*.pem" = "deny";
              "**/id_*" = "deny";
            };
            write = protectedPaths;
            edit = protectedPaths;

            # Everything else is allowed outright — see the note above about the
            # "ask" default for unlisted tools. `powershell` is safe to allow
            # because pi shells out to pwsh, which is not installed here.
            ask_user_question = "allow";
            bg_wait = "allow";
            codemode = "allow";
            contact_supervisor = "allow";
            fetch_content = "allow";
            find = "allow";
            get_search_content = "allow";
            grep = "allow";
            ls = "allow";
            powershell = "allow";
            source_check = "allow";
            subagent = "allow";
            subagent_supervisor = "allow";
            subagents_enable = "allow";
            todo = "allow";
            tool_search = "allow";
            web_enable = "allow";
            web_search = "allow";

            # veridb MCP tools, named mcp__<server>__<tool>. `query` is the one
            # that can mutate data — flip it to "ask" for a confirmation prompt
            # (which blocks headless calls).
            mcp__veridb__describe_table = "allow";
            mcp__veridb__explain_query = "allow";
            mcp__veridb__list_databases = "allow";
            mcp__veridb__list_schemas = "allow";
            mcp__veridb__list_tables = "allow";
            mcp__veridb__query = "allow";
            mcp__veridb__sample_rows = "allow";
            mcp__veridb__search_columns = "allow";
            mcp__veridb__veridb_status = "allow";
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
          pi-guard
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
        "${pi-guard}"
        # Permission gate — the policy is settings.guard below. Supersedes the
        # former repo-local safety.ts: bash is parsed as an AST (so wrapper
        # commands like `sudo rm -rf` are re-checked instead of slipping past a
        # regex), and file paths and MCP tools are gated too.
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

    # The repo's own opencode-quota widget and its fetcher timer were retired on
    # 2026-10-16 — AiOverviewControl's opencode card reports the same Zen quota
    # windows. Its cache files would otherwise sit unread forever.
    home.activation.cleanupOpencodeQuotaWidget = ''
      rm -f "$HOME/.cache/opencode-quota.json" "$HOME/.cache/opencode-stats.json"
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

    # Input diagnostics (RICE §24). libinput's CLI reads /dev/input, so it needs
    # root: `sudo libinput list-devices`. evtest = raw evdev, wev = Wayland events.
    libinput
    evtest
    wev
  ];

  # Those tools open /dev/input/event* (root:input 0660), so membership replaces
  # sudo. Scope: read access to every keystroke device — see the journal entry.
  users.users.vageesh.extraGroups = [ "input" ];
}
