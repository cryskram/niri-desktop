# secrets — NEVER committed (gitignored)

Place company VPN tunnel file here **only as a local file, never commit**.

Supported formats (filenames only, contents never printed):

- WireGuard: `secrets/wg0.conf` or `secrets/company-wg.conf`
  → NixOS will enable it via `networking.wg-quick.interfaces.wg0.configFile = ./secrets/wg0.conf`
  Requires `networkmanager` or `wg-quick` handling; private key stays in the file, not in Git.

- OpenVPN: `secrets/vpn.ovpn` or `secrets/company.ovpn`
  → NixOS will enable it via `services.openvpn.servers.company.config = '' config /path/to/ovpn ''`
  Credentials (auth-user-pass) should be in a separate `secrets/vpn.auth` (also gitignored).

- NetworkManager: Import via `nmcli connection import type openvpn file secrets/vpn.ovpn` or WireGuard via `nmconnection`

After placing the file, rebuild:

```bash
sudo nixos-rebuild switch --flake .#nixos --accept-flake-config
# VPN then supports: systemctl start wg-quick-wg0 / systemctl status openvpn-company
```

Do NOT copy private keys into `configuration.nix` or any file tracked by Git.
If secret management with sops-nix is needed, see `docs/decisions/` and ask before migrating.
