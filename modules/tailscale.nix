# Tailscale — WireGuard-based mesh VPN, separate from the wg0 / Proton tunnels in
# modules/vpn.nix. First login is interactive (`sudo tailscale up`); the node key
# lives in /var/lib/tailscale, outside this repository.
{
  services.tailscale = {
    enable = true;

    # Lets peers reach this node directly instead of through DERP relays.
    openFirewall = true;

    # "client" sets networking.firewall.checkReversePath = "loose", required when
    # routes arrive from more than one tunnel (wg0, Proton, exit nodes, accepted
    # subnet routes). Switch to "both" only to advertise an exit node or subnet
    # routes from this machine.
    useRoutingFeatures = "client";

    # Applied at boot by tailscaled-set, so the CLI needs no sudo — and unlike a
    # manual `tailscale set --operator=…` it survives every rebuild.
    # --ssh serves SSH for tailnet clients from inside tailscaled: those packets
    # are handled after WireGuard decryption and never reach the host's sshd, so
    # tailnet logins are identity-based (tailnet ACLs) rather than key-based.
    extraSetFlags = [
      "--operator=vageesh"
      "--ssh"
    ];
  };

  # The module does not trust tailscale0, so tailnet peers could not reach local
  # services (SSH, `tailscale serve`) even with the tunnel up. Trusting the
  # interface delegates access control to the tailnet's ACLs.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
