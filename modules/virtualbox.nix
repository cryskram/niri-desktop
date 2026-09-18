# VirtualBox host — personal (no vendor guest tools committed)
{ ... }:
{
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = [ "vageesh" ];
}
