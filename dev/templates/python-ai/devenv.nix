# Python 3.12 env for AI SDKs that ship prebuilt wheels (krutrim-cloud, opencv,
# moviepy, …). Differs from templates/python on purpose:
#   - python312, not python3: krutrim-cloud requires >=3.10,<3.13 and this
#     machine's python3 is 3.13
#   - LD_LIBRARY_PATH: wheels like opencv-python dlopen libstdc++/libGL/glib,
#     which a Nix python does not put on the loader path, so `import cv2` (and
#     therefore `import krutrim_cloud`) fails without this
#   - ffmpeg: pydub/moviepy shell out to it at runtime
{ pkgs, lib, ... }:
{
  languages.python = {
    enable = true;
    package = pkgs.python312;
    uv.enable = true;
  };

  env.LD_LIBRARY_PATH = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib # libstdc++.so.6
    pkgs.libglvnd # libGL.so.1
    pkgs.glib # libgthread-2.0 / libgobject-2.0
    pkgs.zlib
    pkgs.libx11
    pkgs.libxcb
    pkgs.libxext
    pkgs.libsm
    pkgs.libice
    pkgs.libxrender
    pkgs.freetype
    pkgs.fontconfig
    pkgs.libxfixes
    pkgs.libxrandr
    pkgs.libxi
  ];

  packages = with pkgs; [
    ffmpeg
    ruff
    black
    mypy
    pyright
  ];

  enterShell = ''
    echo "python-ai env: $(python -V) — pip install into .venv, not the shell"
  '';
}
