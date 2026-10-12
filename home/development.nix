# Development toolchains — Home Manager (DEV_ENVIRONMENT §3)
# Machine-level global toolchains; project deps stay in devenv.
# Preserves existing shell/file tooling; adds missing languages + LSPs.
{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    # ── AI agent runtime ──
    # herdr keeps coding-agent terminals alive across ssh/detach (nixpkgs-unstable)
    herdr
    # claude-code is installed by programs.claude-code below (Home Manager module),
    # not listed here — the module owns the package so it can also own ~/.claude.

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
    # gcc + clang both provide bin/c++ -> clang lower priority so gcc wins (DEV fix)
    (lib.lowPrio clang)
    (lib.hiPrio gcc)
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

  # Claude Code — Anthropic's agentic coding CLI. The Home Manager module installs
  # the package (resolved through the unstable overlay in modules/core.nix → 2.1.292)
  # and can own ~/.claude declaratively: settings, context (CLAUDE.md), skills,
  # agents, commands, rules, hooks, lspServers, mcpServers, plugins, marketplaces.
  #
  # Only `enable` is set deliberately: with no `settings`, the module writes
  # nothing into ~/.claude, so `claude /login` and your own edits stay writable.
  # Add options here when you want them tracked in git — note that managed files
  # become read-only store symlinks.
  programs.claude-code.enable = true;
}
