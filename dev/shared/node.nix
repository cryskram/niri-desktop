# shared/node.nix — Node/TypeScript devenv fragment
{ pkgs, ... }:
{
  imports = [ ./common.nix ];
  languages.javascript.enable = true;
  languages.typescript.enable = true;
  packages = with pkgs; [
    nodejs
    pnpm
    yarn
    typescript
    eslint
    prettier
  ];
}
