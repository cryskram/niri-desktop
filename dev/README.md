# dev — personal devenv environments

This directory holds personal development environments that live in `~/niri-desktop` and do NOT modify company repositories until approval.

Structure per `DEV_ENVIRONMENT.md` §12:

```text
dev/
├── README.md
├── shared/          # reusable devenv fragments (language stacks)
│   ├── common.nix
│   ├── go.nix
│   ├── node.nix
│   ├── java.nix
│   ├── python.nix
│   └── rust.nix
├── company/         # personal envs for existing company projects (no Nix in company repo)
│   ├── project-a.nix
│   └── ...
└── templates/       # `devenv init` starters for new personal projects
    ├── go/
    ├── node/
    ├── java/
    ├── python/
    └── rust/
```

## New personal project

```bash
mkdir ~/my-project && cd ~/my-project
devenv init
# copy one of dev/templates/<stack>/devenv.nix + devenv.yaml + .envrc
direnv allow
```

## Existing company project (no Nix files in company repo)

Keep the company repo untouched. Create a personal env here:

```bash
# dev/company/project-a.nix imports the appropriate shared/ fragment
# then in the company repo:
echo "source $(realpath ~/niri-desktop/dev/company/project-a)/.devenv" > .envrc   # or via direnv
# or use: direnv with `source ~/niri-desktop/dev/company/project-a/.envrc`
```

See `dev/shared/` and `dev/company/README.md`.

Do NOT commit company secrets or `.env` files.
