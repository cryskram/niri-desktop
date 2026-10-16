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
      # v2.12.0 moves typebox to peerDependencies:"*" — fixes pi's
      # "Host-provided extension packages must be declared in
      # peerDependencies with a '*' range" loader warning (v2.11.0 declared
      # it as a regular dependency and tripped the stricter check).
      version = "2.13.8";
      src = pkgs.fetchFromGitHub {
        owner = "juicesharp";
        repo = "rpiv-mono";
        tag = "v2.13.8";
        hash = "sha256-s8xMQx1fqInIZjWWroYqEsPWmR8jjrzDWXP+jiL9pyY=";
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
    npmHash = "sha256-Tni3Zcp+QBQB9EZWv2SaFhmQCHVLa8ap7DrE7U50xGU=";
    subdir = "packages/rpiv-ask-user-question";
  };

  # Todo list for the model, rendered as a live overlay that survives /reload
  # and conversation compaction.
  rpiv-todo = rpivExtension {
    pname = "rpiv-todo";
    npmHash = "sha256-+QsYY1Z/CK97vhDSuUnrWtOARzo/xrd/jW2dcInQDe0=";
    subdir = "packages/rpiv-todo";
  };

  # /btw — parallel side conversation in a real pi sub-session, usable while
  # the main agent is still running. Imports only pi's bundled modules.
  pi-btw = plain {
    pname = "pi-btw";
    version = "0.8.0";
    src = pkgs.fetchFromGitHub {
      owner = "dbachelder";
      repo = "pi-btw";
      tag = "v0.8.0";
      hash = "sha256-ktDQhWAmv8AaiVkiNFrpUp5iwRueYZ6dqrLDSCKUxJ0=";
    };
  };

  # Starship-style statusline + opencode-style TUI (owns the footer).
  # zentui — replaces pi-powerline-footer. No npm deps (plain, ships TS source
  # pi loads directly; peers satisfied by host). Configure via `/zentui` at
  # runtime → ~/.pi/agent/zentui.json (components/styles/modelLabel).
  # NOTE: its footer defaults to `starship` mode — harmless now that
  # pi-powerline is gone; use `/zentui` to switch footer style if needed.
  zentui = plain {
    pname = "pi-zentui";
    version = "0.31.0";
    src = pkgs.fetchFromGitHub {
      owner = "lmilojevicc";
      repo = "pi-zentui";
      tag = "v0.31.0";
      hash = "sha256-yE5UXWr1oGGv7oIXLUanbSVv3D3HjmTg0MCSIoi4uqQ=";
    };
  };

  # pi-subagents — async child agents (scout/researcher/oracle/worker/reviewer).
  # Generic for any project: no niri-desktop specific code, works in any cwd.
  pi-subagents = withDeps {
    pname = "pi-subagents";
    version = "0.78.0";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-subagents";
      tag = "v0.78.0";
      hash = "sha256-kTzwkgt+ZVRc5LoPCsryQcmMB9XJ5k5Tptrw3HV+9a8=";
    };
    npmHash = "sha256-SRnuPebtq8Ob7kGucJ5VA3ZEhojpglgbaRXv/hZoN/0=";
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
    version = "0.41.0";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-web-access";
      tag = "v0.41.0";
      hash = "sha256-rO7rj3RVS/79cUpWUZCXktaxJbjLO4QDPezRTn+H120=";
    };
    npmHash = "sha256-LAmr0jojKdzAFwfVGDEjT2QDpQ/0FoGJ1dxgblTeX5w=";
    npmFlags = [
      "--omit=dev"
    ];
  };

  # pi-guard — permission gate for tool calls: bash commands parsed as an AST
  # (so `sudo rm -rf`, `bash -c '…'` and `find -exec rm` are caught, unlike a
  # regex blocklist), file-path globs for read/write/edit, and whole-tool rules
  # for everything else. The policy lives declaratively under `settings.guard`
  # in modules/core.nix — quiet by default, denying/prompting only on
  # destructive operations, which is the opposite of upstream's ask-everything
  # defaults (and of its ask-unknown-tools fallback).
  pi-guard = withDeps {
    pname = "pi-guard";
    version = "1.6.0";
    src = pkgs.fetchFromGitHub {
      owner = "jdiamond";
      repo = "pi-guard";
      tag = "v1.6.0";
      hash = "sha256-il/wRNdV2zLi07b6SBubuJX4R+HXIiV0Bsx0XrWSckE=";
    };
    npmHash = "sha256-nwer1uc8wiOV5v1IPbxN5gMRTP++ihffuFlSjcZb7cU=";
    npmFlags = [
      "--omit=dev"
    ];
  };
}