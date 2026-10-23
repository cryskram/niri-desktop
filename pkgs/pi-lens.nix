# pi-lens — LSP / lint / format / structural feedback for pi.
#
# Pinned from the npm tarball rather than the GitHub tag: the published package
# ships the compiled `dist/`, bundled tree-sitter grammars, rules and skills,
# while the repo's source needs `npm run prepare` (tsc + grammar download + git
# hooks) that a sandbox must not run.
#
# Runtime deps come from the registry (FOD, network allowed):
#   --omit=dev    skips jest/typescript and friends
#   --omit=peer   required — the peers (typebox, @earendil-works/pi-*) are
#                 supplied by the pi host and must not be installed here
#   --ignore-scripts  upstream `prepare` is a build step, not a runtime need
#
# No `bin/` is installed: dist/mcp/*.js import host-provided
# @earendil-works/pi-tui, so the CLIs only run inside a pi host. The extension
# (and its bundled skill) is the deliverable.
{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs,
  cacert,
}:
let
  version = "4.4.4";

  src = fetchurl {
    url = "https://registry.npmjs.org/pi-lens/-/pi-lens-${version}.tgz";
    hash = "sha256-CW7PWQBzEnTCofetJSSeTvU6o6ys8SkUb3LZ6tsGVuo=";
  };

  nodeModules = stdenvNoCC.mkDerivation {
    pname = "pi-lens-node-modules";
    inherit version src;

    nativeBuildInputs = [ nodejs ];
    NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-1E5h0C0aRFylZ1uBy1nNBeWKEW92sRG4Lp4B8jIGFhw=";

    dontFixup = true;
    sourceRoot = "package";

    # The npm tarball has no package-lock.json, so `npm ci` is unavailable and
    # the install resolves from package.json; the FOD hash pins the result.
    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      npm install --omit=dev --omit=peer --ignore-scripts \
        --no-audit --no-fund --loglevel=error
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
  pname = "pi-lens";
  inherit version src;

  sourceRoot = "package";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/pi-lens
    cp -r . $out/lib/node_modules/pi-lens/
    cp -r ${nodeModules} $out/lib/node_modules/pi-lens/node_modules
    runHook postInstall
  '';

  meta = {
    description = "pi-lens — real-time code feedback for pi (LSP, linters, formatters, structural analysis)";
    homepage = "https://github.com/apmantza/pi-lens";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
