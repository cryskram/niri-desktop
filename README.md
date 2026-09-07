# niri-desktop

Reproducible NixOS desktop and developer workstation built around [Niri](https://github.com/YaLTeR/niri) + [Noctalia](https://github.com/noctalia-dev/noctalia-shell) — Tokyo Night Storm, Wayland-native.

![NixOS](https://img.shields.io/badge/NixOS-26.05-blue?logo=nixos)
![Niri](https://img.shields.io/badge/compositor-Niri-7aa2f7)
![Noctalia](https://img.shields.io/badge/shell-Noctalia-414868)
![license](https://img.shields.io/badge/license-MIT-lightgrey)

Single source of truth — clone and rebuild on compatible hardware.

## Showcase

- **Compositor:** Niri scrollable tiling, dynamic workspaces, rounded corners (`12px`), `8px` gaps, rings `2px`
- **Shell:** Noctalia (Quickshell) — island pills, glass/blur, launcher/control-center/wallpaper/lock
- **Theme:** Tokyo Night Storm (centralized tokens, no hard-coded palette)
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
theme/                   — tokens.nix + noctalia-storm.json (Storm palette)
dev/                     — personal devenv definitions (shared/, templates/, company/)
secrets/                 — gitignored VPN/keys (README + .gitkeep tracked)
```

`flake.nix` modules:
`configuration.nix`, `hardware-configuration.nix`, `modules/{core,theme,shell,niri,sddm,docker,direnv,vpn}.nix`, `pi` + `home-manager` modules.

## Desktop

**Stack:** NixOS → Wayland → Niri → Noctalia → utilities (`fuzzel`, `mako`, `swaybg`, `swaylock`).

**Bar (Noctalia islands):** `[launcher|workspaces] [clock] [network|bluetooth|volume|battery|control-center|session]` — per-pill hex, no overflow, survives missing BT/NET/muted/battery states. Panels (network/audio/BT) share Storm tokens.

**Tokens (`theme/tokens.nix`):** `background #24283b`, `surface #2a2f4a`, `accent #7aa2f7`, etc. — change there, not per-file.

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
# WireGuard (detected: ~/Downloads/vageesh.gn-laptop.conf -> secrets/wg0.conf 600)
cp ~/Downloads/vageesh.gn-laptop.conf ~/niri-desktop/secrets/wg0.conf
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
pi --version  # 0.84.4 — keep pi.nix overlay, don't imperatively upgrade
opencode --version  # 1.18.25
```

Known fix: `gcc`/`clang` both provide `bin/c++` → `lib.hiPrio gcc` / `lib.lowPrio clang`; `corepack` bundled in `nodejs_24`.

## Screenshots

> Placeholders — replace with actual captures before publishing.

| Desktop | Terminal | Files |
|---|---|---|
| ![desktop](assets/screenshots/01-desktop.png) | ![terminal](assets/screenshots/02-terminal.png) | ![files](assets/screenshots/03-files.png) |
| Bar + wallpaper + islands | Ghostty + Starship + Tokyo Night | Nautilus + Tela-circle-dark |

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
