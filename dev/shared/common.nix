# shared/common.nix — common devenv helpers
# Imported by all shared/* fragments and company/* envs.
{ pkgs, lib, config, ... }:
{
  # Common services/helpers placeholder — add shared env vars, shell hooks
  env.DEVENV_COMMON = "1";
  # git, gh already global; keep devenv lean
}
