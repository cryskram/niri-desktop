# Development toolchains — Home Manager (DEV_ENVIRONMENT §3)
# Machine-level global toolchains; project deps stay in devenv.
# Preserves existing shell/file tooling; adds missing languages + LSPs.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── Core additions not yet in shell/files ──
    tree
    file
    which
    less
    unzip
    zip
    wget # curl already in systemPackages, also add here for HM isolation
    curl
    openssl
    httpie
    netcat
    dig
    traceroute
    iproute2
    tcpdump
    nmap

    # ── Go ──
    go
    gopls
    delve
    golangci-lint
    gotools

    # ── Java / Kotlin ──
    jdk
    maven
    gradle
    kotlin
    kotlin-language-server

    # ── Node / TypeScript ──
    nodejs
    pnpm
    yarn
    typescript
    eslint
    prettier

    # ── Python ──
    python3
    python3Packages.pip
    python3Packages.virtualenv
    uv
    ruff
    black
    mypy
    pyright

    # ── Rust ──
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt

    # ── C / C++ ──
    gcc
    clang
    gdb
    lldb
    cmake
    ninja
    pkg-config
    clang-tools
    gnumake

    # ── Database / backend CLI clients (DEV_ENVIRONMENT §6) ──
    postgresql
    redis
    sqlite
    mysql84
    mongosh
  ];

  # Ensure uv/pip don't pollute global, but are available
  # No extra config needed — devenv will pin project versions.
}
