# Tailscale

Mesh VPN (WireGuard under the hood), installed through `modules/tailscale.nix`.
Distinct from the wg0 / Proton tunnels in `modules/vpn.nix`: there is no tunnel
file to place, login is interactive, and the node key lives outside the repo in
`/var/lib/tailscale/tailscaled.state` (delete it and you log in again).

What the module sets, and why:

| Setting | Reason |
| --- | --- |
| `openFirewall` (UDP 41641) | Peers can reach this node directly; without it traffic falls back to DERP relays. |
| `useRoutingFeatures = "client"` | Sets `checkReversePath = "loose"`, required because wg0, Proton and accepted Tailscale routes coexist here. |
| `extraSetFlags = [ "--operator=vageesh" ]` | Applied at boot by `tailscaled-set.service`, so the CLI needs no sudo — and, unlike a manual `tailscale set`, survives every rebuild. |
| `firewall.trustedInterfaces = [ "tailscale0" ]` | The module does not add it; without it tailnet peers cannot reach local services (SSH, `tailscale serve`) even with the tunnel up. |

## First login

```bash
sudo tailscale up                            # prints an auth URL — open it, approve the device
sudo tailscale up --hostname=niri-desktop    # optional: this machine's hostname is "nixos"
sudo tailscale set --operator=vageesh        # only if the CLI reports permission denied
```

Enable MagicDNS once in the [admin console](https://login.tailscale.com/admin/dns)
so peers resolve by name (`ssh niri-desktop`) instead of `100.x.y.z`.

## Verify

```bash
tailscale status          # this node + peers, with "direct" or "relay" per path
tailscale ip -4           # this node's tailnet address
tailscale netcheck        # DERP latency and UDP reachability — run this first if it feels slow
tailscale ping <peer>     # reports whether that path is direct or via DERP
```

## Daily use

| Goal | Command |
| --- | --- |
| SSH without keys or open ports | `sudo tailscale up --ssh` once (plus the ACL grant), then `ssh <host>` / `tailscale ssh <host>` |
| Expose a local service to the tailnet | `tailscale serve <port>` → `https://<host>.<tailnet>.ts.net` with automatic TLS; `tailscale serve status`, `tailscale serve reset` |
| Expose it to the public internet | `tailscale funnel <port>` — world-reachable, use sparingly |
| Send all traffic through another node | `sudo tailscale up --exit-node=<peer> --exit-node-allow-lan-access`; undo with `--exit-node=` |
| Accept someone's advertised subnet | `sudo tailscale up --accept-routes` |
| Transfer a file to a peer (Taildrop) | `tailscale file cp ./file.zip <peer>:` then `tailscale file get .` on the peer |
| Disconnect / reconnect | `tailscale down` / `tailscale up` (login persists) |
| Log out entirely | `tailscale logout` — node key discarded, next `up` re-authenticates |
| Script against it | `tailscale status --json \| jq -r '.Peer[] \| "\(.HostName) \(.TailscaleIPs[0]) \(.Online)"'` |
| Debug | `tailscale ping <peer>`, `tailscale bugreport` |

Also integrated into the fuzzel chooser (`vpn-toggle tailscale`, or pick
`tailscale (mesh VPN)` from `Mod+Shift+N`) and `vpn-status` reports its state.
Tailscale is not NetworkManager-managed, so it does **not** appear in DMS's VPN
widget — that widget only lists `nmcli` connections.

## NixOS specifics

- **State:** `/var/lib/tailscale/tailscaled.state`. Never commit it; never delete it casually.
- **`tailscale up` flags are imperative state** kept locally. They survive reboots but are not reproducible from this repo. For routes or an exit node you want declarative, use `extraSetFlags` in `modules/tailscale.nix` instead.
- **Unattended login** (servers, the eventual second machine): `services.tailscale.authKeyFile` plus `extraUpFlags`; the module then drives `tailscaled-autoconnect.service`. An auth key is a credential, so it belongs in a secrets path, never in Git. Services binding to the tailnet address should order themselves `after tailscaled-autoconnect.service`.
- **Becoming an exit node or subnet router** needs `useRoutingFeatures = "both"` (enables IP forwarding) plus `sudo tailscale up --advertise-exit-node` / `--advertise-routes=…`, then approval in the admin console.
- **Upgrades** come from nixpkgs (`services.tailscale.package`); `nix flake update` bumps the daemon.

## Coexistence with wg0 and Proton

- **Proton VPN (full tunnel) breaks direct paths.** Tailscale falls back to relays over 443 — functional, slower. Confirm with `tailscale netcheck`. Fix by enabling Proton split-tunneling, or don't run both.
- **wg0 (company):** watch for route overlap with `100.64.0.0/10` (Tailscale's CGNAT range). `ip route get 8.8.8.8` shows which tunnel currently carries traffic.
- Never activate two exit nodes at once.

## Security

`tailscale0` is a trusted firewall interface, so access control is the tailnet's
ACLs, not the local firewall. Grant by tag rather than by device, keep `funnel`
off unless the exposure is intended, and treat auth keys like passwords.
