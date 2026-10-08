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
      version = "2.11.0";
      src = pkgs.fetchFromGitHub {
        owner = "juicesharp";
        repo = "rpiv-mono";
        tag = "v2.11.0";
        hash = "sha256-lXSj7i0bKuOKdajoJqLukCqNMi6398IxRFgFbXHgUUA=";
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
  # Structured questionnaires the model can put to you.
  rpiv-ask-user-question = rpivExtension {
    pname = "rpiv-ask-user-question";
    npmHash = "sha256-9l+4i3+y2mpYwRhRSwSnNeqV2v34gtZCxDakWbIMa/4=";
    subdir = "packages/rpiv-ask-user-question";
  };

  # Todo list for the model, rendered as a live overlay that survives /reload
  # and conversation compaction.
  rpiv-todo = rpivExtension {
    pname = "rpiv-todo";
    npmHash = "sha256-qm2Q3Kt6OjYtC0R6jFUNrakfUrhLLw39psUCJq+o9Ho=";
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

  # Starship-style statusline + opencode-style TUI (owns the footer).
  # Powerline footer — replaces zentui. Shows git branch, model, tokens,
  # context %, cost, and thinking level with powerline segments. Catppuccin
  # Macchiato palette, Nerd Font aware. Configure via `pi --powerline` or
  # `~/.pi/agent/settings.json` → `powerline`.
  pi-powerline = plain {
    pname = "pi-powerline";
    version = "0.19.1";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-powerline-footer";
      tag = "v0.19.1";
      hash = "sha256-KgRDsu5qCHeWbJvCZgCFWU0yVxv7J5fd3IpKvFV7Pco=";
    };
  };

  # pi-subagents — async child agents (scout/researcher/oracle/worker/reviewer).
  # Generic for any project: no niri-desktop specific code, works in any cwd.
  pi-subagents = withDeps {
    pname = "pi-subagents";
    version = "0.73.1";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-subagents";
      tag = "v0.73.1";
      hash = "sha256-EqWfWHlyXkhWNgov4gQnpnX/Gnz4QjjBBAPcx8Xrvjo=";
    };
    npmHash = "sha256-DZDCLk076bdn/sSSrA8i43h0wKyVbCm6pIoIH8QI9q8=";
    npmFlags = [
      "--omit=dev"
    ];
  };

  # pi-web-access — web search / fetch / source_check for researcher + evidence-auditor.
  # Coexists with native MCP parallel-search — different tool names, no clash:
  #   pi-web-access: web_search, fetch_content, source_check, get_search_content
  #   native MCP: parallel-search.* via pi mcp (OAuth, exposure direct)
  # pi-web-access fallback chain defaults to Exa MCP (zero-config) -> Brave -> Parallel API etc.,
  # and only uses OpenAI Hosted Search when active model is openai/openai-codex, so deepseek/muse untouched.
  pi-web-access = withDeps {
    pname = "pi-web-access";
    version = "0.34.0";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-web-access";
      tag = "v0.34.0";
      hash = "sha256-KYcScVwKKuY393nzHtZBUVvQzBYaVm3JmBxVRuJY8PI=";
    };
    npmHash = "sha256-UN1aKEWbyGntuJmFTdDRMhlm4z6itwm8qiKe9WVhx84=";
    npmFlags = [
      "--omit=dev"
    ];
  };

  # Dummy MCP — local learning harness (stdio). Pinned like other extensions so
  # the build is pure and no ~/.npmrc/CodeArtifact leak affects it.
  # To update deps: edit pi/mcp-servers/dummy/package.json, run
  #   npm install --registry https://registry.npmjs.org
  # in that dir, then `nix build .#dummy-mcp` with a fake hash to capture the
  # correct `npmHash` from the error, same workflow as scripts/update-pi-extensions.py.
  dummy-mcp = withDeps {
    pname = "dummy-mcp";
    version = "0.1.0";
    src = ./mcp-servers/dummy;
    npmHash = "sha256-/NdLtFU/HtPauma49vg9QQv+CaXUJQiR4bj5toyw4O8=";
    npmFlags = [ "--omit=dev" ];
  };
}
