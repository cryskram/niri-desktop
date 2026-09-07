# dev/company — personal envs for existing company projects

Do NOT add `devenv.nix`, `.envrc`, or `.devenv` to the company repository.

Instead, keep a personal devenv here that you activate while working in the company repo.

Example `project-a.nix`:

```nix
# dev/company/project-a.nix — personal Go + Postgres env for company/project-a
{ pkgs, ... }:
{
  imports = [ ../shared/go.nix ];
  languages.go.package = pkgs.go_1_22; # pin if company needs specific version

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_16;
    initialDatabases = [{ name = "project_a_dev"; }];
    listen_addresses = "127.0.0.1";
  };

  env.DATABASE_URL = "postgres://localhost/project_a_dev";
}
```

Usage from company repo checkout (e.g., `~/work/company/project-a`):

```bash
# 1. Create a direnv link that points to this env without touching company repo
echo "source ~/niri-desktop/dev/company/project-a/.envrc" > ~/work/company/project-a/.envrc.personal
# or use a shell hook:
# In ~/work/company/project-a, run:
#   devenv shell --impure --option pure-eval false --file ~/niri-desktop/dev/company/project-a.nix

# Recommended: use `devenv` directly with external file:
#   devenv --file ~/niri-desktop/dev/company/project-a.nix shell
# or symlink devenv:
#   ln -s ~/niri-desktop/dev/company/project-a/devenv.nix ./devenv.nix.personal  # not committed
```

Until company approval, keep all Nix/devenv files here.
