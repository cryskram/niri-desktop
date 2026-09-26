# niri-desktop

Reproducible NixOS desktop and developer workstation built around [Niri](https://github.com/YaLTeR/niri) + [Noctalia](https://github.com/noctalia-dev/noctalia-shell) — Catppuccin Macchiato, Wayland-native.

![NixOS](https://img.shields.io/badge/NixOS-26.05-blue?logo=nixos)
![Niri](https://img.shields.io/badge/compositor-Niri-7aa2f7)
![Noctalia](https://img.shields.io/badge/shell-Noctalia-414868)
![license](https://img.shields.io/badge/license-MIT-lightgrey)

Single source of truth — clone and rebuild on compatible hardware.

## Showcase

- **Compositor:** Niri scrollable tiling, dynamic workspaces, rounded corners (`12px`), `8px` gaps, rings `2px`
- **Shell:** Noctalia (Quickshell) — island pills, glass/blur, launcher/control-center/wallpaper/lock
- **Theme:** Catppuccin Macchiato (centralized tokens, no hard-coded palette)
- **Login:** SDDM Astronaut (Wayland, `QtMultimedia` + Bibata cursor)
- **Workstation:** `devenv` + `direnv` + Docker, full language toolchains

> Spec: [`RICE.md`](RICE.md) · Architecture: [`AGENTS.md`](AGENTS.md) · Dev setup: [`DEV_ENVIRONMENT.md`](DEV_ENVIRONMENT.md) · Decision: [`docs/decisions/noctalia.md`](docs/decisions/noctalia.md)

## Quick start

```bash
git clone https://github.com/cryskram/niri-desktop.git ~/niri-desktop
cd ~/niri-desktop
nix flake check
sudo nixos-rebuild switch --flake .#nixos --accept-flake-config
# reboot to SDDM -> Niri
```

Requirements: NixOS `26.05` `x86_64`, flakes enabled, Intel graphics, `1920×1080` (scales to multi-monitor).

## Structure

```
flake.nix                — inputs: nixpkgs, unstable, home-manager, pi.nix, noctalia
configuration.nix        — system (boot, networking, pipewire, locale)
hardware-configuration.nix — generated, don't edit casually
modules/                 — core.nix (flake wiring, pi, HM), theme/shell/niri/sddm/docker/direnv/vpn.nix
home/                    — niri.nix, noctalia.nix, theme.nix, shell.nix, git.nix, development.nix, ...
theme/                   — tokens.nix + noctalia-macchiato.json (Noctalia palette)
pi/                      — pi prompts, skills, extensions (mcp-adapter, pi-btw, rpiv-todo/ask-user-question, pi-powerline-footer, pi-subagents, pi-web-access, pi-ui, safety/querion), rules, theme
dev/                     — personal devenv definitions (shared/, templates/, company/)
secrets/                 — gitignored VPN/keys (README + .gitkeep tracked)
```

`flake.nix` modules:
`configuration.nix`, `hardware-configuration.nix`, `modules/{core,theme,shell,niri,sddm,docker,direnv,vpn}.nix`, `pi` + `home-manager` modules.

## Desktop

**Stack:** NixOS → Wayland → Niri → Noctalia → utilities (`fuzzel`, `mako`, `swaybg`, `swaylock`).

**Bar (Noctalia islands):** `[launcher|workspaces] [clock] [network|bluetooth|volume|battery|control-center|session]` — per-pill hex, no overflow, survives missing BT/NET/muted/battery states. Panels (network/audio/BT) share Storm tokens.

**Tokens (`theme/tokens.nix`):** `background #24273a`, `surface #363a4f`, `accent #c6a0f6`, etc. — change there, not per-file.

**Fonts:** Inter (UI), JetBrains Mono (mono/code), Noto Emoji.

**Icons:** `Tela-circle-dark` (crisp `@2x`), cursor `Bibata-Modern-Classic 24`.

## Keybindings (Niri)

| Bind | Action |
|---|---|
| `Mod+T` / `Mod+Return` | Ghostty |
| `Mod+D` | Noctalia launcher (fallback fuzzel) |
| `Mod+Ctrl+V` | clipboard |
| `Mod+Ctrl+C` | control-center |
| `Mod+P` | session/power |
| `Super+Alt+L` | lock |
| `Mod+M` / `Mod+Shift+M` | display extend ↔ mirror (`wl-mirror` onto HDMI-A-1) |
| `Mod+Shift+N` | VPN toggle (`wg-quick-wg0`) |
| `Mod+Shift+S` / `Print` | region/full screenshot → Satty |
| `Mod+Shift+R` | screen record |
| `Mod+1..9`, arrows, etc. | Niri defaults (see `home/niri.nix` includes `default-config.kdl`) |

Multi-monitor: `eDP-1 1920×1080@60 scale 1.15` + `HDMI-A-1 2560×1440@59.95 scale 1.0` extend (mirror via `wl-mirror`). `output` position `auto` (toggle is temporary `niri msg output position set`).

## Developer workstation

Machine tools (HM `home/development.nix` + `applications.nix`) vs project envs (`devenv`).

**Core:** `git`/`gh`/`git-lfs`, `neovim`/`lazygit`/`yazi`, `fzf`/`zoxide`/`eza`/`bat`/`fd`/`ripgrep`/`jq`/`yq`, `curl`/`wget`/`httpie`, `tree`/`file`...

**Languages:**
- Go `go`/`gopls`/`delve`/`golangci-lint`/`gotools`
- Java/Kotlin `jdk`/`maven`/`gradle`/`kotlin` + `kotlin-language-server`, `jetbrains.idea`/`goland`/`clion`
- Node `nodejs`/`pnpm`/`yarn`/`typescript`/`eslint`/`prettier`
- Python `python3`/`uv`/`ruff`/`black`/`mypy`/`pyright`
- Rust `rustc`/`cargo`/`rust-analyzer`/`clippy`/`rustfmt`
- C/C++ `gcc` (hiPrio) / `clang` (lowPrio) / `gdb`/`lldb`/`cmake`/`ninja`/`clang-tools`

**Containers:** `virtualisation.docker` + `compose`/`buildx`/`lazydocker`, user in `docker` group.

**DB clients:** `postgresql`/`redis`/`sqlite`/`mysql84`/`mongosh` (services via Docker/devenv).

**Apps:** Chrome, Ghostty, Nautilus, Spotify, Slack, Discord, `figma-linux`, Bruno/Postman.

## devenv + direnv

```bash
# new personal project
mkdir ~/my-app && cd ~/my-app
cp -r ~/niri-desktop/dev/templates/go/* .  # or node/java/python/rust
direnv allow  # auto-activates devenv

# inside devenv:
devenv test
```

Templates are **standalone** (`languages.*` inline) — copied project doesn't depend on `~/niri-desktop`. Shared fragments in `dev/shared/` are for `dev/company/` personal envs that don't touch company repos (see `dev/company/README.md`).

```bash
# company repo (no Nix files until approval)
# dev/company/project-a.nix.example -> dev/company/<real>.nix
# then in company checkout: devenv --file ~/niri-desktop/dev/company/<real>.nix shell
```

Enable globally: `modules/direnv.nix` + `home/direnv.nix` (`nix-direnv`).

## VPN & secrets

WireGuard/OpenVPN via `modules/vpn.nix` — **never committed**.

```bash
# WireGuard (detected: <name>.conf -> secrets/wg0.conf 600)
cp ~/Downloads/<name>.conf ~/niri-desktop/secrets/wg0.conf
chmod 600 ~/niri-desktop/secrets/wg0.conf
sudo nixos-rebuild switch --flake .#nixos --accept-flake-config

Mod+Shift+N        # or vpn-toggle
vpn-status         # up/down
systemctl status wg-quick-wg0
journalctl -u wg-quick-wg0 -n 30
# NM import to show inside Noctalia network panel:
nmcli connection import type wireguard file ~/niri-desktop/secrets/wg0.conf
```

`.gitignore` blocks `secrets/*` (except `README.md`/`.gitkeep`), `*.ovpn`, `wg*.conf`, `.env*`, `.direnv`/`.devenv`, `*.key`/`*.pem`/`.age`. See `secrets/README.md`.

## Validate & rebuild

```bash
nix fmt
nix flake check          # validates niri config via `niri validate`
nixos-rebuild dry-build --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos --accept-flake-config

devenv --version; direnv version; docker --version; docker compose version
go version; node --version; python --version; rustc --version; java --version
pi --version  # 0.87.1 — keep pi.nix overlay, don't imperatively upgrade
opencode --version  # 1.18.25
pi --list           # should show mcp-adapter, pi-btw, rpiv-todo, rpiv-ask-user-question, pi-powerline-footer, pi-subagents, pi-web-access, pi-ui
```

Known fix: `gcc`/`clang` both provide `bin/c++` → `lib.hiPrio gcc` / `lib.lowPrio clang`; `corepack` bundled in `nodejs_24`.

## Updating inputs

Never run bare `nix flake update` — it bumps every input at once, and two of them can cost an hour of local compilation. Update one input at a time and preview the price first.

```bash
cd ~/niri-desktop
git status --short                   # must be clean
git tag pre-update-$(date +%Y%m%d)   # cheap rollback point

nix flake update <one-input>         # e.g. nixpkgs, noctalia, home-manager

# what will actually compile locally? (nix flake check does NOT tell you)
nix build --dry-run --no-link '.#nixosConfigurations."nixos".config.system.build.toplevel' 2>&1 \
  | grep -oE '[a-z0-9]{32}-[^ ]+\.drv' | sed 's|^[a-z0-9]*-||; s|\.drv$||' | sort -u

nix flake check
sudo nixos-rebuild switch --flake .#nixos --accept-flake-config
```

`nix flake check` validates evaluation only — it says nothing about build cost. The dry-run list is what tells you what will compile.

### Cost per input

| Input | Cost when updated | Why |
|---|---|---|
| `noctalia` | **always** a source build (~10–20 min) | the upstream flake publishes no binary cache |
| `nixpkgs` | kernel modules (~10 min) when its version moves | |
| `nixpkgs-unstable` | usually cached | Hydra builds unstable |
| `pi` | cached | `pi.cachix.org` is in this flake's `nixConfig` |
| `home-manager`, `catppuccin`, `spicetify-nix` | seconds | config only |

Rule of thumb: `noctalia` is the one that can cost 20+ minutes; everything else is cheap — `nixpkgs` bumps mainly rebuild the kernel modules. A reasonable cadence is `nixpkgs` + `home-manager` + `nixpkgs-unstable` every few weeks, and `noctalia` only when you want the new version.

### If a pi extension hash mismatches

A `nixpkgs` bump of `nodejs`/`npm` changes what the pi extension fixed-output derivations produce:

```
error: hash mismatch in fixed-output derivation '...-pi-web-access-node-modules-0.31.0.drv'
         specified: sha256-...
            got:    sha256-...
```

That is not a breakage — the build is reporting the new hash. Set that extension's `npmHash = pkgs.lib.fakeHash;` in `pi/packages.nix`, build it, then paste the reported value:

```bash
nix build --no-link --impure --expr '
  let pkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux;
      ext = import ./pi/packages.nix { inherit pkgs; };
  in ext.pi-web-access'   # or ext.mcp-adapter / ext.pi-subagents / ext.rpiv-todo
```

Pi subagents (scout/researcher/evidence-auditor/oracle/worker/reviewer) are generic — work in any project cwd, not just `niri-desktop`. Defaults: `deepseek-v4-flash` for children, oracle `muse-spark` (never `deepseek-pro`). Researcher uses `pi-web-access` (`web_search`/`fetch_content`/`source_check`); it coexists with MCP `parallel-search` (`mcp-oauth` via `mcp-adapter`) on different tool namespaces.

See [Rollback & tags](#rollback--tags) for backing out of an update.

## Screenshots

> Placeholders — replace with actual captures before publishing.

| Desktop | Terminal | Files |
|---|---|---|
| ![desktop](assets/screenshots/01-desktop.png) | ![terminal](assets/screenshots/02-terminal.png) | ![files](assets/screenshots/03-files.png) |
| Bar + wallpaper + islands | Ghostty + Starship + Catppuccin Macchiato | Nautilus + Tela-circle-dark |

| Launcher | Control Center | Multi-monitor |
|---|---|---|
| ![launcher](assets/screenshots/04-launcher.png) | ![control-center](assets/screenshots/05-control-center.png) | ![multi](assets/screenshots/06-multi.png) |
| Noctalia launcher (`Mod+D`) | Noctalia control-center (`Mod+Ctrl+C`) | `eDP-1` + `HDMI-A-1` extend/mirror (`Mod+M`) |

Capture:
```bash
mkdir -p assets/screenshots
# fullscreen / region
 grim assets/screenshots/01-desktop.png
 # with windows open, then:
 grim assets/screenshots/02-terminal.png
```
`assets/screenshots/` is tracked — add real `*.png` before push (keep placeholders until then).

## Rollback & tags

```
v0.1-foundation, v1.0, v1.1 (SDDM cursor + wl-mirror)
```

```bash
sudo nixos-rebuild switch --rollback
git log --oneline --tags
```

## Contributing

Public repo — no secrets, no `hardware-configuration.nix` churn without reason, small validated commits (`nix flake check` + `dry-build` before push).

## License

MIT — see `LICENSE` (if absent, treat as MIT for now).
