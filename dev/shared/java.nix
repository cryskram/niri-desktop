# shared/java.nix — Java/Kotlin devenv fragment
{ pkgs, ... }:
{
  imports = [ ./common.nix ];
  languages.java = {
    enable = true;
    jdk.package = pkgs.jdk17; # default 17; override per-project: jdk.package = pkgs.jdk for latest
  };
  packages = with pkgs; [
    maven
    gradle
    kotlin
    kotlin-language-server
  ];
}
