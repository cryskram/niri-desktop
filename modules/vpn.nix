# VPN — declarative placeholder (DEV_ENVIRONMENT §14)
# Company tunnel file lives in `secrets/` (gitignored, never commit).
# Supported: WireGuard (wg-quick) or OpenVPN (services.openvpn) or NetworkManager import.
# This module does NOT print or embed secrets; it only references external files.
# After placing `secrets/wg0.conf` or `secrets/vpn.ovpn`, rebuild:
#   sudo nixos-rebuild switch --flake .#nixos --accept-flake-config
#   systemctl status wg-quick-wg0  /  systemctl status openvpn-company  /  nmcli connection show
{ lib, pkgs, ... }:
let
  hasWg = builtins.pathExists ../secrets/wg0.conf;
  hasWgAlt = builtins.pathExists ../secrets/company-wg.conf;
  hasOvpn = builtins.pathExists ../secrets/vpn.ovpn;
  hasOvpnAlt = builtins.pathExists ../secrets/company.ovpn;
in
{
  # WireGuard via wg-quick — if `secrets/wg0.conf` exists locally
  networking.wg-quick.interfaces = lib.mkMerge [
    (lib.mkIf hasWg {
      wg0.configFile = ../secrets/wg0.conf;
      # Do not autostart by default; use `systemctl start wg-quick-wg0`
      autostart = false;
    })
    (lib.mkIf (hasWgAlt && !hasWg) {
      wg0.configFile = ../secrets/company-wg.conf;
      autostart = false;
    })
  ];

  # OpenVPN — if `secrets/vpn.ovpn` exists locally
  services.openvpn.servers = lib.mkMerge [
    (lib.mkIf hasOvpn {
      company = {
        config = "config ${../secrets/vpn.ovpn}";
        autoStart = false;
        # If the ovpn references `auth-user-pass secrets/vpn.auth`, that auth file
        # must also be placed in `secrets/` (gitignored). Do NOT embed credentials in Nix.
      };
    })
    (lib.mkIf (hasOvpnAlt && !hasOvpn) {
      company = {
        config = "config ${../secrets/company.ovpn}";
        autoStart = false;
      };
    })
  ];

  # Ensure VPN tooling is available regardless (no secrets needed)
  environment.systemPackages = with pkgs; [
    wireguard-tools
    openvpn
    networkmanager-openvpn
  ];

  # Helpful comment for `nixos-rebuild` evaluation when no file exists:
  # If neither file exists, this module is a no-op (apart from installing tools).
  # Place the file provided by company, rebuild, then:
  #   sudo systemctl start wg-quick-wg0  # or openvpn-company
  #   nmcli connection import type wireguard file secrets/wg0.conf  # alternative via NM
}
