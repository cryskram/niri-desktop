# SSH access.
#
# Two paths, deliberately:
#   - tailnet: Tailscale SSH answers port 22 itself (modules/tailscale.nix enables
#     it with --ssh). Those packets are handled inside tailscaled after WireGuard
#     decryption and never reach the kernel, so sshd below is bypassed for tailnet
#     clients, and access is granted by the tailnet's ACLs rather than by keys.
#   - everything else (localhost, LAN, other networks): this sshd, key-only.
{ ... }:
{
  services.openssh = {
    enable = true;

    # NixOS defaults to PasswordAuthentication = true and
    # KbdInteractiveAuthentication = true; this box is key-only.
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };

    # Port 22 stays closed to the LAN and the public internet. tailscale0 is a
    # trusted interface (modules/tailscale.nix), so reaching sshd over the tailnet
    # is possible in principle — but Tailscale SSH claims tailnet port 22, so sshd
    # serves localhost (and the LAN, if you ever set openFirewall = true).
    openFirewall = false;
  };

  # Authorized client keys, one per line, e.g.
  #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI… user@laptop"
  # Public keys are safe to commit; never add private keys here.
  users.users.vageesh.openssh.authorizedKeys.keys = [ ];
}
