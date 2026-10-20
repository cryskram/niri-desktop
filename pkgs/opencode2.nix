# OpenCode 2 — the daemon-based rewrite of the OpenCode coding agent.
#
# nixpkgs has no v2 packaging (its `opencode` is still the 1.x line, and even
# master trails our pin), and npm's `@opencode/cli` is only a thin wrapper: its
# postinstall swaps in a platform-specific binary, so with install scripts
# disabled the wrapper does nothing but print "postinstall script was not run".
# Fetch that platform package directly instead.
#
# Replaces the 1.x binary system-wide: v2 owns the `opencode` command and reads
# the same config/credential locations (~/.config/opencode/opencode.json,
# ~/.local/share/opencode/auth.json), so no migration is needed for the repo's
# config or the AiOverviewControl quota pill.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "2.1.1";

  # Platform package for x86_64 with AVX2 (the installer's default variant;
  # `cli-linux-x64-baseline` is the fallback for pre-AVX2 CPUs, and
  # `cli-linux-x64-musl` the musl build).
  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${finalAttrs.version}.tgz";
    hash = "sha256-ZFkQV+pZPpoRN01GMMIkmTDY8zWYrws+AhN0k4YKsXs=";
  };

  sourceRoot = "package";

  # The binary links only glibc (libc/libm/libdl/libpthread); autoPatchelfHook
  # rewrites the interpreter for NixOS. No other shared libraries are needed.
  nativeBuildInputs = [ autoPatchelfHook ];

  # node_modules-style tarball: no build of our own, just install the binary.
  dontBuild = true;
  # Do NOT strip: this is a bun-compiled single-file binary, and stripping it
  # makes bun fall back to its own CLI (`--version` reports the bun version and
  # `auth` prints "reserved for future use by Bun") instead of running opencode.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/opencode $out/bin/opencode
    runHook postInstall
  '';

  meta = {
    description = "OpenCode 2 — open source AI coding agent (daemon-based rewrite)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "opencode";
  };
})
