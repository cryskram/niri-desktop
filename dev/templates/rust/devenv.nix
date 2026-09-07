{ pkgs, ... }:
{
  languages.rust.enable = true;
  packages = with pkgs; [
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt
  ];
}
