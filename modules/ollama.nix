# Ollama — local inference backend for TapFix's `local` provider profile.
# Binds 0.0.0.0 so the n8n Docker container can reach it across the bridge.
# Reference: https://wiki.nixos.org/wiki/Ollama
{ pkgs, ... }:
{
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    # Pulled on activation; the first switch downloads ~2 GB for this model.
    loadModels = [ "qwen2.5:3b" ];
  };

  # Docker gives each user-defined network its own bridge (n8n sits on 172.18.0.0/16,
  # not docker0), and that bridge name changes if the network is recreated. Allow the
  # whole docker address space to 11434 instead of pinning an interface name.
  # NOTE: extraInputRules is nftables-only; this host runs the iptables backend,
  # so the rule goes through extraCommands (a value there is silently ignored).
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp -s 172.16.0.0/12 --dport 11434 -j nixos-fw-accept
  '';

  # CLI for manual `ollama pull` / `ollama list` alongside the service.
  environment.systemPackages = with pkgs; [ ollama ];
}
