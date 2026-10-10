# VPN — declarative placeholder (DEV_ENVIRONMENT §14)
# Company and Proton tunnel files live in `secrets/` (gitignored, never commit).
# Supported: WireGuard (wg-quick) or OpenVPN (services.openvpn) or NetworkManager import.
# This module does NOT print or embed secrets; it only references external files.
# After placing `secrets/wg0.conf` or `secrets/vpn.ovpn` (company) or
# `secrets/proton.conf` (Proton VPN WireGuard), rebuild:
#   sudo nixos-rebuild switch --flake .#nixos --accept-flake-config
#   systemctl status wg-quick-wg0  /  systemctl status wg-quick-proton  /  systemctl status openvpn-company  /  nmcli connection show
#
# Proton VPN: two options —
#   1) GUI app (proton-vpn): `protonvpn-app` → login, pick server (easiest, dynamic)
#   2) WireGuard config: account.protonvpn.com → Downloads → WireGuard →
#      download .conf for a server, save as `secrets/proton.conf` (600), rebuild,
#      then `systemctl start wg-quick-proton` (static, fastest, no GUI)
{ lib, pkgs, ... }:
let
  hasWg = builtins.pathExists ../secrets/wg0.conf;
  hasWgAlt = builtins.pathExists ../secrets/company-wg.conf;
  hasProton = builtins.pathExists ../secrets/proton.conf;
  hasProtonAlt = builtins.pathExists ../secrets/proton-wg.conf;
  hasOvpn = builtins.pathExists ../secrets/vpn.ovpn;
  hasOvpnAlt = builtins.pathExists ../secrets/company.ovpn;
in
{
  # WireGuard via wg-quick — if `secrets/wg0.conf` exists locally (company)
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
    (lib.mkIf hasProton {
      proton.configFile = ../secrets/proton.conf;
      autostart = false;
    })
    (lib.mkIf (hasProtonAlt && !hasProton) {
      proton.configFile = ../secrets/proton-wg.conf;
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

  # Allow toggling wg-quick without password (for vpn-toggle + Noctalia/Waybar)
  security.sudo.extraRules = [
    {
      users = [ "vageesh" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start wg-quick-wg0";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop wg-quick-wg0";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart wg-quick-wg0";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/wg-quick up wg0";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/wg-quick down wg0";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start wg-quick-proton";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop wg-quick-proton";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart wg-quick-proton";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/wg-quick up proton";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/wg-quick down proton";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Ensure VPN tooling is available regardless (no secrets needed)
  environment.systemPackages = with pkgs; [
    wireguard-tools
    openvpn
    networkmanager-openvpn
    proton-vpn # Official GUI — binary is `protonvpn-app` → login, pick server (dynamic)
  ];

  # Helpful comment for `nixos-rebuild` evaluation when no file exists:
  # If nothing exists, this module is a no-op (apart from installing tools).
  # Place the file, rebuild, then:
  #   sudo systemctl start wg-quick-wg0      # company
  #   sudo systemctl start wg-quick-proton   # Proton WireGuard
  #   sudo systemctl status wg-quick-proton  # check
  #   nmcli connection import type wireguard file secrets/proton.conf  # alternative via NM
  # Or just run the GUI: `protonvpn-app` → login → pick server (no file needed).
}
