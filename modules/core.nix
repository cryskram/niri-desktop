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

  # Official Bruno MCP server (pkgs/bruno-mcp.nix), hoisted for the mcp.json
  # entry below. Loaded on demand by the adapter like every other server.
  brunoMcp = pkgs.callPackage ../pkgs/bruno-mcp.nix { };

  # pi-lens (pkgs/pi-lens.nix) — LSP / lint / format / structural feedback while
  # the agent edits. Ships an extension plus four skills.
  piLens = pkgs.callPackage ../pkgs/pi-lens.nix { };

  # Slack MCP server (pkgs/slack-mcp-server.nix) — korotovsky/slack-mcp-server,
  # chosen over Slack's official remote MCP because that one needs a
  # directory-published/internal app plus workspace-admin approval of the MCP
  # integration, while this one runs off a plain user token. Hoisted so the
  # wrapper below can exec it.
  slackMcp = pkgs.callPackage ../pkgs/slack-mcp-server.nix { };

  # The server authenticates at start-up and exits before serving when the token
  # is bad (`invalid_auth`), so credentials have to be in the environment before
  # exec. They come from gitignored files under secrets/ — the same pattern as
  # querion's tokenFile — so nothing secret can reach mcp.json or the Nix store.
  # Raw files (not a sourced .env) are deliberate: pi-guard denies writes to
  # `**/secrets/**` and `**/*.env`, and sourcing a user-editable shell file buys
  # nothing here.
  #
  # Two routes, upstream's own priority order (xoxp > xoxb > xoxc/xoxd):
  #   slack-xoxc-token + slack-xoxd-token  browser session (no Slack app at all)
  #   slack-mcp-token                      single xoxp/xoxb token (needs an app)
  # Only the matching variables are exported; upstream would otherwise prefer a
  # stale xoxp over a fresh browser session.
  #
  # Caches are pinned under ~/.cache: upstream otherwise writes
  # .users_cache.json / .channels_cache_v2.json into the cwd, littering every
  # project the server is started from. They are also what makes `#channel` and
  # `@username_dm` resolution work, so never run this with `-no-cache`.
  slackMcpWrapped = pkgs.writeShellScriptBin "slack-mcp-server" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}:$PATH

    secrets_dir="''${SLACK_MCP_SECRETS_DIR:-$HOME/niri-desktop/secrets}"

    if [ -n "''${SLACK_MCP_XOXC_TOKEN:-}" ] && [ -n "''${SLACK_MCP_XOXD_TOKEN:-}" ]; then
      : # browser session already exported
    elif [ -r "$secrets_dir/slack-xoxc-token" ] && [ -r "$secrets_dir/slack-xoxd-token" ]; then
      export SLACK_MCP_XOXC_TOKEN="$(tr -d '\r\n' < "$secrets_dir/slack-xoxc-token")"
      export SLACK_MCP_XOXD_TOKEN="$(tr -d '\r\n' < "$secrets_dir/slack-xoxd-token")"
    else
      token="''${SLACK_MCP_XOXP_TOKEN:-}"
      [ -n "$token" ] || token="''${SLACK_MCP_XOXB_TOKEN:-}"
      if [ -z "$token" ] && [ -r "$secrets_dir/slack-mcp-token" ]; then
        token="$(tr -d '\r\n' < "$secrets_dir/slack-mcp-token")"
      fi
      if [ -z "$token" ]; then
        echo "slack-mcp-server: no Slack credentials — write the xoxc/xoxd pair to $secrets_dir/slack-{xoxc,xoxd}-token, or an xoxp token to $secrets_dir/slack-mcp-token (see docs/slack.md)" >&2
        exit 78
      fi
      # Upstream prioritises xoxp over xoxb, so the token is exported under the
      # variable that matches its prefix rather than guessing.
      case "$token" in
        xoxb-*) export SLACK_MCP_XOXB_TOKEN="$token" ;;
        *) export SLACK_MCP_XOXP_TOKEN="$token" ;;
      esac
    fi

    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/slack-mcp"
    mkdir -p "$cache_dir"
    export SLACK_MCP_USERS_CACHE="$cache_dir/users_cache.json"
    export SLACK_MCP_CHANNELS_CACHE="$cache_dir/channels_cache_v2.json"

    exec ${slackMcp}/bin/slack-mcp-server "$@"
  '';

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
    (
      final: prev:
      let
        unstable = import nixpkgs-unstable {
          system = prev.stdenv.hostPlatform.system;
          config = prev.config;
        };
      in
      {
        # OpenCode 2 replaces the 1.x line: same `opencode` command, same config
        # (~/.config/opencode/opencode.json) and credential (~/.local/share/
        # opencode/auth.json) locations, so the repo config and AiOverviewControl's
        # quota card keep working. nixpkgs has no v2 yet, so it comes from the npm
        # platform package — see pkgs/opencode2.nix for why that is not the wrapper.
        opencode = final.callPackage ../pkgs/opencode2.nix { };
        pi-coding-agent = unstable.pi-coding-agent;

        # herdr — agent multiplexer / terminal workspace for coding agents.
        herdr = unstable.herdr;

        # claude-code — Anthropic's agentic coding CLI (unfree; releases far more
        # often than stable follows: 2.1.292 on unstable vs 2.1.223 in stable 26.05).
        # nixpkgs wraps its runtime deps (ripgrep, bubblewrap, socat); the former
        # claude-code-bin attribute was merged into it upstream.
        claude-code = unstable.claude-code;

        # Dux Shell — Wayland shell (bar/launcher/notifications/lock/wallpaper),
        # renamed from DankMaterialShell in nixpkgs 2026-10-20 and now 2.0.0. The
        # `dms` binary and unit names are unchanged; the config dir moved to
        # ~/.config/dms. quickshell is overlaid too because the shell's module
        # still installs it and stable 26.05 ships an older one.
        dux-shell = unstable.dux-shell;
        quickshell = unstable.quickshell;
      }
    )
  ];

  programs.pi.coding-agent = {
    enable = true;
    package = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent;

    # pi-lens would otherwise `go install` / `gem install` / pip-install the
    # language servers and linters it needs. On NixOS that is imperative drift
    # into the home directory, and this repo already provides the servers
    # declaratively through devenv (dev/shared/*.nix: gopls, typescript,
    # pyright, rust-analyzer, kotlin-language-server), so they are on PATH in any
    # project shell. Missing servers now degrade instead of installing.
    environment = {
      PI_LENS_DISABLE_LSP_INSTALL.value = "1";
      PI_LENS_DISABLE_TOOL_INSTALL.value = "1";
    };

    settings = {
      defaultProvider = "jev";
      defaultModel = "auto";
      defaultThinkingLevel = "high";
      theme = "catppuccin-macchiato";
      defaultTools = [ "+codemode" ]; # keep read/bash/edit/write + codemode (JS orchestration, parallel calls, image models)

      # Built-in MCP off: pi-mcp-adapter (wired in `extensions` below) registers the
      # same `/mcp` command and replaces it. Declaring it here rather than letting
      # the adapter append it keeps settings.json declarative, and it silences pi's
      # "built-in MCP was not loaded" warning on every start.
      extensions = [ "-builtin:mcp" ];

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
        # Children run with ambient extensions OFF — a detached async runner is
        # spawned with `--no-extensions`, and an in-process child only loads the
        # parent's ambient set when host === "runner" (pi-subagents
        # child-launch.ts). So anything a child needs must be named here:
        #   pi-web-access  → web_search/fetch/source_check for researcher and
        #                    evidence-auditor (foreground children otherwise lack them).
        #   jev-router.ts  → registers the *virtual* model `jev/auto`. Without it a
        #                    child launched as `--model jev/auto:high` dies before
        #                    its first turn with `Model "jev/auto:high" not found`,
        #                    which is exactly what killed the researcher run on
        #                    2026-10-23. The router's triage handler no-ops inside
        #                    children (PI_SUBAGENT_CHILD=1), so this only restores
        #                    model routing + compaction there.
        defaultSubagentOnlyExtensions = [
          "${piPackages.pi-web-access}"
          "${../pi/extensions/jev-router.ts}"
        ];
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
      # is listed as an outright allow. Adding a *new extension* means adding its
      # tools here (`/guard list` shows what is in effect, and the prompt UI offers
      # to save a permanent allow). Adding an *MCP server* means adding its
      # direct `<server>_<tool>` names (see the MCP block below) — the proxy `mcp`
      # alone is not enough, because the model prefers the direct tools.
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

            # File tools: reads are unrestricted, writes/edits respect
            # protectedPaths below.
            #
            # Reads are deliberately ungated (any file, including private keys and
            # .env contents): that is the explicit preference, and the trade-off is
            # that such values do reach the transcript, which /sync archives.
            read = "allow";
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

            # MCP. pi-mcp-adapter reaches servers two ways, and pi-guard sees a
            # different tool name for each, so both need rules:
            #   `mcp`               — the proxy tool (model calls it with
            #                         mcp({search})/mcp({tool}); also what headless
            #                         `pi -p` sessions use)
            #   `<server>_<tool>`   — direct tools the adapter registers as
            #                         first-class pi tools at startup ("direct tools
            #                         refreshed (+N)"), e.g. veridb_list_databases.
            #                         The model prefers these, so without these
            #                         rules every MCP call prompts — and the
            #                         prompt's "save permanent allow" cannot write
            #                         the store-symlinked user settings.json, so it
            #                         offers the project's .pi/settings.json instead.
            #                         These rules are that save, done declaratively.
            # Adding a future MCP server means adding its direct names here too;
            # find them in session files (grep '"toolName"' under
            # ~/.pi/agent/sessions) or `/mcp-adapter tools`.
            mcp = "allow";
            # veridb (9 tools).
            veridb_describe_table = "allow";
            veridb_explain_query = "allow";
            veridb_list_databases = "allow";
            veridb_list_schemas = "allow";
            veridb_list_tables = "allow";
            veridb_query = "allow";
            veridb_sample_rows = "allow";
            veridb_search_columns = "allow";
            veridb_status = "allow";
            # pi-lens (13 pi tools, the authoritative list from dist's `piName`
            # fields — the docs undercount it). Five are always active, five load on
            # demand by pi_lens_activate_tools, which the model calls itself — so
            # the loader needs a rule too, or activating anything prompts.
            lens_diagnostics = "allow";
            module_report = "allow";
            project_report = "allow";
            effective_config = "allow";
            read_symbol = "allow";
            read_enclosing = "allow";
            symbol_search = "allow";
            pi_lens_activate_tools = "allow";
            ast_grep_search = "allow";
            ast_grep_outline = "allow";
            lsp_navigation = "allow";
            lens_diagnostic_mark = "allow";
            # ast_grep_replace DOES write (pattern → rewrite across files). It is
            # allowed because a refactor is its whole point, but note the gap:
            # its targets come from an array param (`paths`), and pi-guard's glob
            # matcher only reads string params, so protectedPaths does not apply
            # to it. Flip to "ask" if you want a confirmation on every rewrite.
            ast_grep_replace = "allow";

            # bruno (7 tools).
            bruno_list_collections = "allow";
            bruno_list_requests = "allow";
            bruno_get_request = "allow";
            bruno_execute_request = "allow";
            bruno_run_collection = "allow";
            bruno_list_environments = "allow";
            bruno_get_environment = "allow";
            # slack (korotovsky/slack-mcp-server; the 6 tools enabled in mcp.json).
            # All allowed outright per Vageesh 2026-10-22 ("whitelist slack mcp
            # things"): posting goes out as Vageesh in a work workspace, so this
            # can post silently headless (subagents, `pi -p`) — flip back to "ask"
            # to fail closed again.
            slack_channels_list = "allow";
            slack_conversations_history = "allow";
            slack_conversations_replies = "allow";
            slack_conversations_search_messages = "allow";
            slack_users_search = "allow";
            slack_conversations_add_message = "allow";
            # slack-message extension (../pi/extensions/slack-message.ts) — chat.update
            # and chat.delete, which the MCP server does not wrap. Fixing a typo stays
            # quiet; deleting asks (Vageesh, 2026-10-22), so it fails closed headless.
            slack_edit_message = "allow";
            slack_delete_message = "ask";

            # Google Workspace extension tools (pi/extensions/google-workspace).
            # pi-guard matches tool names exactly, so all of them are listed;
            # google_drive_write (trash/delete) and google_api (arbitrary API call)
            # are the two worth flipping to "ask" — remember that "ask" blocks
            # headless calls. google_drive_export writes a local file, which the
            # path rules never see, because only path-matched tools are globbed.
            google_accounts = "allow";
            google_api = "allow";
            google_docs_create = "allow";
            google_docs_read = "allow";
            google_docs_write = "allow";
            google_drive_export = "allow";
            google_drive_read = "allow";
            google_drive_search = "allow";
            google_drive_write = "allow";
            google_sheets_batch = "allow";
            google_sheets_create = "allow";
            google_sheets_read = "allow";
            google_sheets_write = "allow";
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
      # pi-lens ships four skills (ast-grep, LSP navigation, rule authoring).
      "${piLens}/lib/node_modules/pi-lens/skills"
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
      # phoenix — the shared-dev-VM deploy tool (leaf-engineering/phoenix, private,
      # so a path rather than a flake input). Single SKILL.md, no sibling assets.
      "--skill"
      "/home/vageesh/Projects/TAP/phoenix/skills/phoenix"
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
          mcp-adapter
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
        # MCP client — replaces the built-in MCP support (see settings.extensions
        # above). One `mcp` proxy tool, lazy server connections, idle servers
        # stopped after 10 min, OAuth tokens in the OS keychain.
        "${mcp-adapter}"
        # pi-lens — LSP diagnostics/navigation, linters, formatters and ast-grep
        # structural rules on every write. Registers 11 tools (see the guard rules
        # below). Directory, not index.js: pi resolves package.json's
        # `pi.extensions` and needs the bundled grammars/rules beside dist.
        "${piLens}/lib/node_modules/pi-lens"
        # Permission gate — the policy is settings.guard below. Supersedes the
        # former repo-local safety.ts: bash is parsed as an AST (so wrapper
        # commands like `sudo rm -rf` are re-checked instead of slipping past a
        # regex), and file paths and MCP tools are gated too.
        ../pi/extensions/jev-router.ts
        # Querion session archive — /sync uploads pi sessions for on-the-go reading.
        # Configured via xdg.configFile."querion/config.json" (home-manager block below).
        ../pi/extensions/querion-sync.ts
        # Editor stash — Alt+S parks the draft and returns a clean editor, Alt+S
        # again restores it (port of pi-powerline-footer's stash, footer and all
        # else dropped). /stash, /stash-history, /stash-clear. State rides the
        # session branch via appendEntry, so /reload and resume keep it.
        ../pi/extensions/stash.ts
        # Slack message edit/delete — chat.update and chat.delete, the two Web API
        # methods the Slack MCP server does not wrap (v1.3.0 has no such tools).
        # Reads the MCP server's own credential files, so there is one Slack setup,
        # not two. Channel names are NOT resolved here (#channel / @username_dm live
        # in the MCP server's caches), so callers pass IDs or a message permalink.
        # See docs/slack.md § Editing and deleting.
        ../pi/extensions/slack-message.ts
        # Google Workspace — `/google` adds Google accounts the way /login picks a
        # provider (personal and Workspace-managed side by side), and 13 tools work
        # on Sheets, Docs and Drive with the selected account's own token. See
        # docs/google-workspace.md. Pass the directory (not index.ts): Nix copies a
        # single file path alone into the store, dropping the sibling module it
        # imports; a directory copies whole, and pi resolves <dir>/index.ts itself.
        ../pi/extensions/google-workspace
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

    # pi-btw (/btw, Alt+B) builds its side sub-session with its own
    # DefaultResourceLoader, so the wrapper's ambient `--extension` set is NOT
    # present there. The default model `jev/auto` is a *virtual* model registered
    # by jev-router.ts, so without that extension BTW resolves provider "jev" as a
    # plain provider, finds no API key, and fails with "No API key found for jev."
    # BTW's only config surface is this file (keys: `extensions`, `workspace`), so
    # loading the router into the sub-session is what makes BTW inherit the main
    # thread's routing instead of a fixed model.
    home.file.".pi/agent/btw.json".text = builtins.toJSON {
      extensions = [ "${../pi/extensions/jev-router.ts}" ];
    };

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

    # MCP servers. pi-mcp-adapter owns MCP now and reads the same files the
    # built-in did (Pi 0.99+ reads ~/.pi/agent/mcp.json and .pi/mcp.json; the
    # adapter also accepts ~/.config/mcp/mcp.json), so declarations did not move
    # and `pi mcp add` / `pi mcp list` still operate on this file.
    # pi-web-access already provides web_search/fetch/source_check, so the
    # parallel-search/deepwiki/chrome-devtools MCPs are redundant. The local
    # dummy harness that once lived here has been removed now that the MCP
    # wiring is understood; add servers as their own entries below.
    # Toggling a server:
    #   globally (here) → add `enabled = false;` to its entry. Verified against
    #     the adapter: doctor then reports `veridb: disabled`. Note the adapter's
    #     OWN configs (.mcp.json / mcp-adapter.json) use `disabled = true`
    #     instead, and that key is ignored in pi's mcp.json
    #     ("Ignored Pi mcp.json settings: disabled").
    #   per project    → `/mcp` then ctrl+d on the server, or
    #     `/mcp-adapter disable <name>` — writes <project>/.pi/mcp-adapter.json
    #     and needs `/reload`. `enable` reverses it.
    #   check          → `node <adapter>/cli.js doctor` (enabled servers only)
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
        # Bruno — official API-collections MCP (usebruno/bruno-mcp, pkgs/bruno-mcp.nix).
        # Both workspaces are pinned (flags are repeatable), so the server exposes
        # exactly these and skips auto-discovery's fallbacks. Reads list/inspect;
        # execute_request/run_collection RUN real requests via the bundled bru, so
        # treat their output as live traffic — per-request auth comes from the
        # collections' own env files, nothing extra to sign in to.
        bruno = {
          command = "${pkgs.nodejs}/bin/node";
          args = [
            "${brunoMcp}/lib/node_modules/@usebruno/mcp/dist/index.js"
            "--workspace"
            "/home/vageesh/Documents/bruno/TAP"
            "--workspace"
            "/home/vageesh/Documents/bruno/PERSONAL"
          ];
        };
        # Slack — korotovsky/slack-mcp-server (pkgs/slack-mcp-server.nix), token
        # auth instead of Slack's admin-approved OAuth MCP (see docs/slack.md).
        # The enabled-tools list is deliberately six entries: unset, the server
        # registers everything it has, including usergroup writes and
        # conversations_join/leave/mark. Write tools are not registered by default
        # unless named, so conversations_add_message is named to make posting (and
        # DMing people) possible at all. Posting is additionally gated in
        # settings.guard below. `channels_list` + `users_search` are what resolve
        # "message xyz" to a `@username_dm` target through the server's caches.
        slack = {
          command = "${slackMcpWrapped}/bin/slack-mcp-server";
          args = [
            "--transport"
            "stdio"
            "--enabled-tools"
            "channels_list,conversations_history,conversations_replies,conversations_search_messages,users_search,conversations_add_message"
          ];
          # Non-secret knobs. The server keeps conversations_add_message DISABLED
          # unless SLACK_MCP_ADD_MESSAGE_TOOL is set (verified: unset refuses with
          # "by default, the conversations_add_message tool is disabled"). "true"
          # allows any channel or DM the credential can reach; a comma-separated
          # channel-ID list restricts posting (`!C123` = everything except C123).
          # SLACK_MCP_USER_AGENT / SLACK_MCP_CUSTOM_TLS are needed by some
          # Enterprise workspaces (set the user agent to the browser's own),
          # SLACK_MCP_LOG_LEVEL takes debug/info/warn/error.
          env.SLACK_MCP_ADD_MESSAGE_TOOL = "true";
        };
      };
    };

    # pi-web-access config (web_search / fetch_content / source_check).
    # Search and plain fetch need no keys (Exa search, direct HTTP fetch), but the
    # answer and summary features call a provider directly, so they cannot use the
    # virtual router model: with the default jev/auto they fail with "Virtual model
    # jev/auto must be routed before streaming". Pinning one concrete model here
    # fixes answer mode, the summary workflow and the curator everywhere, including
    # inside subagents. Swap the pair below rather than hand-editing the file.
    # (Free options exist — e.g. opencode/cat-jam-free — but this pair is verified.)
    home.file.".pi/agent/web-search.json".text = builtins.toJSON {
      workflow = "none";
      summaryModel = "opencode/claude-haiku-4-5";
      fetch = {
        answerProvider = "opencode";
        answerModel = "claude-haiku-4-5";
      };
    };

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
    # Nix tooling for pi-lens: it drives language servers/formatters found on PATH,
    # and this repo has no devenv shell (dev/shared/*.nix covers go/node/python/
    # rust/java elsewhere). Nix coverage is LSP + nixfmt; servers start lazily on
    # the first edit in that language.
    nil
    nixfmt-rfc-style
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
