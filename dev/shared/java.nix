# shared/java.nix — Java/Kotlin devenv fragment
{ pkgs, ... }:
{
  imports = [ ./common.nix ];
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
