# shared/rust.nix — Rust devenv fragment
{ pkgs, ... }:
{
  imports = [ ./common.nix ];
  languages.rust.enable = true;
  packages = with pkgs; [
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt
  ];
}
