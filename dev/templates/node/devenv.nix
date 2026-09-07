{ pkgs, ... }:
{
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
