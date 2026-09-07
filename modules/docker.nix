# Docker — declarative, mandatory (DEV_ENVIRONMENT §4)
# User wants Docker NOT Podman. Enables daemon + buildx + compose.
# Reference: https://wiki.nixos.org/wiki/Docker
{ pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    # Compose already includes `docker compose`; buildx added below.
    daemon.settings = {
      # Keep logs bounded
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };

  # Ensure buildx is available (already in docker package, but also as plugin)
  environment.systemPackages = with pkgs; [
    docker-compose
    docker-buildx
    lazydocker
  ];

  # User can run docker without sudo after next login (group added declaratively)
  users.users.vageesh.extraGroups = [ "docker" ];
}
