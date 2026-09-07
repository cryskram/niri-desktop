{ pkgs, ... }:
{
  languages.java = {
    enable = true;
    jdk.package = pkgs.jdk;
  };
  packages = with pkgs; [
    maven
    gradle
    kotlin
    kotlin-language-server
  ];
}
