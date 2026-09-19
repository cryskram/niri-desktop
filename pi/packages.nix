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
    npmFlags = [
      "--omit=dev"
      # pi supplies @earendil-works/* through its bundled virtual modules;
      # do not pull them from the registry.
      "--legacy-peer-deps"
    ];
  };

  # Structured questionnaires the model can put to you.
  # Runtime deps: @juicesharp/rpiv-config (+ its i18n peer), typebox.
  rpiv-ask-user-question = withDeps {
    pname = "rpiv-ask-user-question";
    version = "2.10.1";
    src = pkgs.fetchFromGitHub {
      owner = "juicesharp";
      repo = "rpiv-mono";
      tag = "v2.10.1";
      hash = "sha256-kgULSuw55OIqoF36kPyl69PCoDyajducrq3jeENnVKM=";
    };
    npmHash = "sha256-JY4Y6vjY9g0haoEQNz1Zk6L0FJHoy+We7/93X/uxs58=";
    npmFlags = [
      "--omit=dev"
      "--legacy-peer-deps"
      # Monorepo: install only this workspace, not every sibling's deps.
      "--include-workspace-root=false"
      "--workspace=@juicesharp/rpiv-ask-user-question"
    ];
    subdir = "packages/rpiv-ask-user-question";
  };

  # Powerline-style status bar for the pi editor.
  powerline-footer = plain {
    pname = "pi-powerline-footer";
    version = "0.17.1";
    src = pkgs.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-powerline-footer";
      tag = "v0.17.1";
      hash = "sha256-yLy6p/58NHbjP3zT6Kp4T6zMwqRq0L1t4X7OMONZXuI=";
    };
  };

  # Starship-style statusline + opencode-style TUI.
  # Note: its footer defaults to `starship`, which overlaps pi-powerline-footer.
  # Set the footer to `native` (or hide one of them) via `/zentui` at runtime.
  zentui = plain {
    pname = "pi-zentui";
    version = "0.24.0";
    src = pkgs.fetchFromGitHub {
      owner = "lmilojevicc";
      repo = "pi-zentui";
      tag = "v0.24.0";
      hash = "sha256-Puk0I1xyl6pDzitjCAiG4anWmeCGyONYr9C68+5xC+0=";
    };
  };
}
