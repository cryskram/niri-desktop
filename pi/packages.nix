# Third-party pi extensions, pinned as Nix derivations.
#
# pi loads an extension from a path; a directory is resolved through the
# `pi.extensions` field of its package.json. Extensions that import bare
# modules outside pi's bundled set (typebox, @earendil-works/*) need their own
# node_modules, so those get one built from the upstream registry.
#
# Wired into pi via `programs.pi.coding-agent.extensions` in modules/core.nix.
{ pkgs }:
let
  # Extension with no runtime dependencies beyond pi's bundled modules:
  # ship the source tree as-is (pi loads TypeScript directly).
  plain =
    {
      pname,
      version,
      src,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname version src;
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -r . $out/
        runHook postInstall
      '';
      meta.description = "pi extension: ${pname}";
    };

  # node_modules fetched straight from the registry as a fixed-output
  # derivation, pinned by `hash`. The upstream lockfiles carry `resolved`
  # entries without `integrity` (nested dev dependencies of
  # @earendil-works/pi-coding-agent), which nixpkgs' lockfile parser rejects,
  # so the lockfile is not used. `--omit=dev` keeps only runtime dependencies.
  nodeModules =
    {
      pname,
      version,
      src,
      hash,
      npmFlags ? [ ],
    }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "${pname}-node-modules";
      inherit version src;

      nativeBuildInputs = [ pkgs.nodejs ];
      NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = hash;

      dontFixup = true;

      buildPhase = ''
        runHook preBuild
        export HOME="$TMPDIR"
        npm ci --ignore-scripts --no-audit --no-fund --loglevel=error \
          ${pkgs.lib.escapeShellArgs npmFlags}
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -r node_modules $out/node_modules
        runHook postInstall
      '';
    };

  # Extension with npm runtime dependencies: ship the source tree plus the
  # fetched node_modules, so pi resolves the dependencies next to the extension.
  withDeps =
    {
      pname,
      version,
      src,
      npmHash,
      npmFlags ? [ ],
      # Subdirectory holding the extension, for monorepo sources.
      subdir ? ".",
    }:
    pkgs.runCommand "${pname}-${version}"
      {
        meta.description = "pi extension: ${pname}";
        passthru.extensionPath = subdir;
      }
      ''
        mkdir -p $out
        cp -r ${src}/. $out/
        chmod -R u+w $out
        rm -rf $out/node_modules
        cp -r ${
          nodeModules {
            inherit
              pname
              version
              src
              npmFlags
              ;
            hash = npmHash;
          }
        }/node_modules $out/node_modules
      '';
  # Both rpiv extensions ship from the same monorepo release and need only their
  # own workspace installed (a sibling @juicesharp/rpiv-config plus the i18n
  # peer). typebox and @earendil-works/* come from pi's bundled modules.
  rpivExtension =
    {
      pname,
      npmHash,
      subdir,
    }:
    withDeps {
      inherit pname npmHash subdir;
      version = "2.10.1";
      src = pkgs.fetchFromGitHub {
        owner = "juicesharp";
        repo = "rpiv-mono";
        tag = "v2.10.1";
        hash = "sha256-kgULSuw55OIqoF36kPyl69PCoDyajducrq3jeENnVKM=";
      };
      npmFlags = [
        "--omit=dev"
        "--legacy-peer-deps"
        # Monorepo: install only this workspace, not every sibling's deps.
        "--include-workspace-root=false"
        "--workspace=@juicesharp/${pname}"
      ];
    };
in
{
  # MCP (Model Context Protocol) servers for pi.
  # Runtime deps: @modelcontextprotocol/*, ajv, zod, undici, open, smol-toml, …
  mcp-adapter = withDeps {
    pname = "pi-mcp-adapter";
    version = "2.34.0";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-mcp-adapter";
      tag = "v2.34.0";
      hash = "sha256-YpiJROIG0/U81wAoImjktbg/d5wGnc6o130IlOrTyEE=";
    };
    npmHash = "sha256-xrr7EUMsOEta1wH8IWrep8R2lRLDlKo1pcAiqfO6nlE=";
    # --omit=dev only. Do NOT add --legacy-peer-deps here: it suppresses peer
    # resolution, and @modelcontextprotocol/ext-apps declares
    # @modelcontextprotocol/sdk as a required (non-optional) peer that its
    # runtime dist/src/app.js actually imports. Skipping it drops sdk, express
    # and hono, and ext-apps then fails with "Cannot find module".
    # The @earendil-works/* peers need no suppression either: their lockfile
    # entries are local file: links, so npm ci skips them on its own and pi
    # supplies them through its bundled virtual modules.
    npmFlags = [
      "--omit=dev"
    ];
  };

  # Structured questionnaires the model can put to you.
  rpiv-ask-user-question = rpivExtension {
    pname = "rpiv-ask-user-question";
    npmHash = "sha256-JY4Y6vjY9g0haoEQNz1Zk6L0FJHoy+We7/93X/uxs58=";
    subdir = "packages/rpiv-ask-user-question";
  };

  # Todo list for the model, rendered as a live overlay that survives /reload
  # and conversation compaction.
  rpiv-todo = rpivExtension {
    pname = "rpiv-todo";
    npmHash = "sha256-GpCwN6upmIYw6hzFR1Vlpmt6GYow2j9crCZVwJviaas=";
    subdir = "packages/rpiv-todo";
  };

  # /btw — parallel side conversation in a real pi sub-session, usable while
  # the main agent is still running. Imports only pi's bundled modules.
  pi-btw = plain {
    pname = "pi-btw";
    version = "0.6.1";
    src = pkgs.fetchFromGitHub {
      owner = "dbachelder";
      repo = "pi-btw";
      tag = "v0.6.1";
      hash = "sha256-/kvyhDRZe2C7uCs8gElBI4s2duYBKgYOVwrjNOnsif8=";
    };
  };

  # pi-powerline-footer — powerline status bar (replaces zentui for footer usefulness).
  # Chosen over zentui starship: async git (+/*/? counts, 1s TTL), live thinking-level
  # indicator (rainbow for high/xhigh/max), context gauge (70% yellow / 90% red live during
  # streaming), Nerd Font auto-detect, narrower useful segments on 1920x1080.
  # zentui editor/working-line features kept via pi-ui widget instead.
  pi-powerline-footer = plain {
    pname = "pi-powerline-footer";
    version = "0.18.0";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-powerline-footer";
      tag = "v0.18.0";
      hash = "sha256-yjUUL1Wdp88tjnV9plIVLkK9jg4EdvIz3UuPzxpZENU=";
    };
  };

  # pi-subagents — async child agents (scout/researcher/oracle/worker/reviewer).
  # Generic for any project: no niri-desktop specific code, works in any cwd.
  pi-subagents = withDeps {
    pname = "pi-subagents";
    version = "0.71.0";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-subagents";
      tag = "v0.71.0";
      hash = "sha256-KUnrfinRPiEPPdj0pd06MWnYncQmjiQvGySmGqdvwEg=";
    };
    npmHash = "sha256-hriNyUN6UDHXc5JdrTULFcQ9kHlt5OXppYflYbkOpkk=";
    npmFlags = [
      "--omit=dev"
    ];
  };

  # pi-web-access — web search / fetch / source_check for researcher + evidence-auditor.
  # Coexists with MCP parallel-search (mcp-oauth) — different tool names, no clash:
  #   pi-web-access: web_search, fetch_content, source_check, get_search_content
  #   MCP parallel-search: parallel-search.* via mcp-adapter (OAuth, directTools)
  # pi-web-access fallback chain defaults to Exa MCP (zero-config) -> Brave -> Parallel API etc.,
  # and only uses OpenAI Hosted Search when active model is openai/openai-codex, so deepseek/muse untouched.
  pi-web-access = withDeps {
    pname = "pi-web-access";
    version = "0.31.0";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-web-access";
      tag = "v0.31.0";
      hash = "sha256-ykR2slh8MkxxbP660h0rvk2Y7SaKv+Cw/lJC21JqGW8=";
    };
    npmHash = "sha256-myr93/Xichm+8/9GtL87tQNZuHCKHH9R592JEFmhiZg=";
    npmFlags = [
      "--omit=dev"
    ];
  };
}
