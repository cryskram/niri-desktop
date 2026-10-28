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
    ├── python-ai/   # python312 + native libs for prebuilt AI wheels
    └── rust/
```

### Why `python-ai` exists

Nix's `python3` is 3.13, and SDKs such as `krutrim-cloud` pin `>=3.10,<3.13`, so
they need `python312`. They also depend on wheels like `opencv-python`, which
`dlopen` `libstdc++`/`libGL`/glib — libraries a Nix Python does not put on the
loader path, so `import cv2` (and therefore `import krutrim_cloud`) fails with
`libstdc++.so.6: cannot open shared object file`. The template sets
`env.LD_LIBRARY_PATH` with `lib.makeLibraryPath` and adds `ffmpeg` for
pydub/moviepy. Do **not** `pip install` into the shell — use the project venv:

```bash
cp -r ~/niri-desktop/dev/templates/python-ai/. ~/my-ai-project/
cd ~/my-ai-project && direnv allow
uv pip install krutrim-cloud
python -c 'import krutrim_cloud, cv2'   # both verified importable
```

`pip install` against the system Python cannot work here at all: the Nix Python
ships no `pip` module, and `python3 -m pip` answers `No module named pip`.

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
