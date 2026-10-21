# Official Bruno MCP server (@usebruno/mcp) — lets pi discover, inspect and run
# the Bruno API collections on disk.
#
# Not published on npm and the repo has no tags, so this pins main HEAD and
# rebuilds on the next explicit bump only.
#
# Deliberately NOT pkgs.buildNpmPackage: 23 lockfile entries (notably the
# @usebruno/* family and `yaml`) carry no `resolved` URL, so the offline
# install that buildNpmPackage prepares fails with ENOTCACHED however the
# prefetcher is configured. Fixed-output derivations may use the network, so
# this follows the repo's own `withDeps` pattern (pi/packages.nix) and runs a
# plain `npm ci` instead.
#
# Execution (`execute_request`, `run_collection`) shells out to `@usebruno/cli`
# (pinned 4.0.0 in the server's own dependencies) resolved from its own
# node_modules — no separate bru CLI package is needed.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nodejs,
  cacert,
}:
let
  version = "0.1.0";
  rev = "97ff645ba8d578b7e6504fee1ac476d0c171086b";

  src = fetchFromGitHub {
    owner = "usebruno";
    repo = "bruno-mcp";
    inherit rev;
    hash = "sha256-DOLAgFE6RgBeQ+WR/XdiLKB5nNWT43rY3JqxZwJKelM=";
  };

  # Full install including dev dependencies: typescript is needed to build and
  # jest to run the repo's own suite. Same shape as `withDeps`, minus --omit.
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "bruno-mcp-node-modules";
    inherit version src;

    nativeBuildInputs = [ nodejs ];
    NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-QOHCrhwH6BzHfpPtvGUN0geVMffAS3NBL1KLBMew1x0=";

    dontFixup = true;

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      npm ci --ignore-scripts --no-audit --no-fund --loglevel=error
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r node_modules/. $out/
      runHook postInstall
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "bruno-mcp";
  inherit version src;

  nativeBuildInputs = [ nodejs ];
  dontFixup = true;

  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR"
    cp -r ${nodeModules} node_modules
    node node_modules/typescript/bin/tsc
    runHook postBuild
  '';

  # The repo's own jest suite: a broken upstream pin fails the build instead of
  # failing at MCP call time.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME="$TMPDIR"
    node --experimental-vm-modules node_modules/jest/bin/jest.js --ci
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/@usebruno/mcp
    cp -r package.json dist node_modules $out/lib/node_modules/@usebruno/mcp/
    runHook postInstall
  '';

  meta = {
    description = "Official Bruno MCP server — pi access to Bruno API collections";
    homepage = "https://github.com/usebruno/bruno-mcp";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bruno-mcp";
  };
}
