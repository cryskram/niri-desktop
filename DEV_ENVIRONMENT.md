# Developer Environment Architecture

## Goal

Build a complete, reproducible NixOS developer workstation while keeping project repositories portable for coworkers who do not use Nix.

The existing `niri-desktop` repository is the single source of truth.

Do NOT create another repository.

---

# 1. Architecture

```text
                         ~/niri-desktop
                               │
              ┌────────────────┴────────────────┐
              │                                 │
       MACHINE ENVIRONMENT               DEVELOPMENT ENVIRONMENTS
              │                                 │
       NixOS + Home Manager                 devenv
              │                                 │
       ┌──────┼─────────┐                     │
       │      │         │                     │
     Apps   CLI tools  Services              │
       │      │         │                     │
       └──────┴─────────┘                     │
              │                               │
              │                         direnv activation
              │                               │
              └──────────────┬────────────────┘
                             │
                      Project repositories
                             │
              ┌──────────────┴──────────────┐
              │                             │
        New personal projects         Existing company projects
              │                             │
      devenv.nix + devenv.yaml        NO Nix files required
      + .envrc                        until company approval
              │                             │
              │                    External dev definitions
              │                    live in niri-desktop
              │
              └──────────────────────────────
```

---

# 2. NixOS / Home Manager owns the workstation

These are machine-level tools and applications.

## Core development tools

### Version control

* git
* gh
* git-lfs

### Shell / terminal utilities

* zsh
* starship
* fzf
* zoxide
* eza
* bat
* fd
* ripgrep
* jq
* yq
* tree
* wget
* curl
* unzip
* zip
* file
* which
* less

### Editors / terminal development

* neovim
* LazyVim configuration
* lazygit
* yazi

### AI development

* pi
* opencode
* devenv
* direnv

Pi remains the primary coding agent.

OpenCode remains available as an additional coding agent/provider.

---

# 3. Languages and development ecosystems

Provide the commonly required toolchains globally, while project-specific versions/dependencies belong inside devenv.

## Go

* go
* gopls
* delve
* golangci-lint
* gotools

## Java / Kotlin

* JDK
* Maven
* Gradle
* Kotlin
* Kotlin language server/tooling where appropriate

JetBrains IDEs:

* IntelliJ IDEA
* GoLand

Prefer the appropriate nixpkgs package when available.

## JavaScript / TypeScript

* Node.js
* npm
* corepack
* pnpm
* yarn
* TypeScript
* eslint
* prettier

Do NOT globally install project dependencies.

Project dependencies belong to the project package manager/devenv.

## Python

* Python
* pip
* uv
* virtualenv
* ruff
* black
* mypy
* pyright

Prefer `uv` for Python project dependency management where appropriate.

## Rust

* rustc
* cargo
* rust-analyzer
* clippy
* rustfmt

## C / C++

* gcc
* gdb
* cmake
* ninja
* pkg-config
* clang
* clang-tools
* lldb

## General build tooling

* make
* cmake
* ninja
* pkg-config
* gcc
* clang

---

# 4. Containers

Docker is mandatory.

Do NOT use Podman.

Install and configure:

* docker
* docker-compose / Docker Compose support
* docker buildx
* lazydocker

Enable the Docker daemon declaratively through NixOS.

The Docker daemon should be available to the development user without requiring unnecessary manual setup.

Reference:
https://wiki.nixos.org/wiki/Docker

---

# 6. Database / backend tooling

Global CLI tools:

* postgresql client
* redis client
* sqlite
* mysql client
* mongosh where available

Do not run every database globally.

Development databases should generally run through Docker/devenv services.

Examples:

```text
PostgreSQL
Redis
MongoDB
MySQL
RabbitMQ
Kafka
```

Use Docker Compose or devenv services depending on project requirements.

---

# 7. API / networking tools

Install:

* httpie
* curl
* wget
* openssl
* netcat
* dig
* traceroute
* iproute2
* tcpdump
* nmap

Useful API clients:

* Bruno
* Postman

Prefer lightweight CLI tools where possible.

---

# 8. Developer desktop applications

Install declaratively through NixOS/Home Manager where supported.

Required applications:

* Google Chrome
* Spotify
* Slack
* Discord
* Figma
* IntelliJ IDEA
* GoLand
* Ghostty
* Nautilus
* Yazi

For applications that are not cleanly available through nixpkgs, use an appropriate declarative Nix-compatible packaging mechanism rather than falling back to random manual installations.

Do not introduce imperative installers unless absolutely necessary.

---

# 9. GitHub / Git workflow

Git is mandatory.

Configure:

```text
git
gh
git-lfs
```

Global Git configuration should include:

* sensible default branch
* useful aliases
* diff configuration
* credential integration
* GPG/SSH signing support if configured
* GitHub CLI authentication

Never store authentication tokens in this repository.

---

# 10. devenv

`devenv` is the preferred project environment system.

For NEW projects:

```text
project/
├── devenv.nix
├── devenv.yaml
├── .envrc
└── ...
```

Example workflow:

```bash
devenv init
direnv allow
```

Project-specific dependencies belong here.

Examples:

```text
Go version
Node version
JDK version
Python version
PostgreSQL
Redis
Kafka
environment variables
development services
CLI tools
build tooling
```

Use `devenv` rather than manually constructing large project-specific flakes unless there is a concrete reason to use a raw Flake.

---

# 11. direnv

Direnv is mandatory.

It should be configured globally through NixOS/Home Manager.

Project environments should automatically activate when entering a directory.

Typical new-project structure:

```text
project/
├── devenv.nix
├── devenv.yaml
├── .envrc
└── .gitignore
```

`.envrc` should activate devenv.

Never blindly allow an `.envrc` from an untrusted repository.

Review it first, then:

```bash
direnv allow
```

`.direnv` must never be committed.

Personal `.envrc` files should generally not be committed to company repositories.

---

# 12. Existing company repositories

This is a critical requirement.

Do NOT modify existing company repositories simply to add Nix/devenv configuration.

Until company approval exists:

```text
company-project/
├── existing project files
└── NO devenv.nix
```

Instead maintain personal development environments inside:

```text
~/niri-desktop/dev/
```

Suggested structure:

```text
dev/
├── README.md
├── shared/
│   ├── common.nix
│   ├── go.nix
│   ├── node.nix
│   ├── java.nix
│   ├── python.nix
│   └── rust.nix
│
├── company/
│   ├── project-a.nix
│   ├── project-b.nix
│   └── project-c.nix
│
└── templates/
    ├── go/
    ├── node/
    ├── java/
    ├── python/
    └── rust/
```

These environments are personal tooling and do not modify company repositories.

After company approval, the relevant environment can be migrated into the company project itself.

---

# 13. Environment separation

Global workstation:

```text
NixOS/Home Manager
```

Project environment:

```text
devenv
```

Automatic activation:

```text
direnv
```

Containers:

```text
Docker
```

Therefore:

```text
NixOS
 └── workstation
      ├── editors
      ├── terminals
      ├── browsers
      ├── communication apps
      ├── developer CLIs
      ├── Docker
      ├── direnv
      └── devenv

Project
 └── devenv
      ├── language version
      ├── dependencies
      ├── services
      ├── environment variables
      └── project tooling
```

---

# 14. VPN

A company-provided VPN tunnel configuration exists locally.

The VPN configuration must NEVER be committed to Git.

First identify the tunnel format:

```text
WireGuard
OpenVPN
NetworkManager profile
other
```

Then configure it appropriately through NixOS.

If it is WireGuard:

```text
networking.wg-quick
```

or another appropriate NixOS networking module.

If it is OpenVPN:

```text
services.openvpn
```

Do not copy private keys or credentials into the Git repository.

Preferred structure:

```text
niri-desktop/
└── secrets/
```

The actual secrets must be excluded from Git and preferably managed with a dedicated secret-management solution.

The VPN should support:

```text
start
stop
status
```

without requiring manual recreation of the tunnel.

---

# 15. Secrets

NEVER commit:

* VPN private keys
* VPN credentials
* API keys
* GitHub tokens
* cloud credentials
* SSH private keys
* `.env` files containing secrets
* Pi authentication
* OpenCode authentication

The repository must remain safe to keep public.

Use:

```text
.env
.env.local
.age
sops
```

or another proper secret mechanism as appropriate.

---

# 16. Repository structure

Target structure:

```text
niri-desktop/
├── flake.nix
├── flake.lock
├── configuration.nix
├── hardware-configuration.nix
├── home.nix
│
├── RICE.md
├── AGENTS.md
├── DEV_ENVIRONMENT.md
│
├── modules/
│   ├── desktop/
│   ├── development/
│   ├── applications/
│   ├── docker.nix
│   ├── direnv.nix
│   └── vpn.nix
│
├── home/
│   ├── shell.nix
│   ├── git.nix
│   ├── neovim.nix
│   └── applications.nix
│
└── dev/
    ├── README.md
    ├── shared/
    ├── company/
    └── templates/
```

The exact module structure may be changed if a better architecture is found.

Avoid unnecessary abstraction.

---

# 17. Reproducibility rules

Machine configuration:

```text
flake.nix
flake.lock
NixOS
Home Manager
```

Project configuration:

```text
devenv.nix
devenv.yaml
devenv.lock
```

Automatic activation:

```text
direnv
```

Runtime isolation:

```text
Docker
```

Everything committed to Git must be reproducible.

Do not use `curl | bash` installers for development tools unless there is no reasonable declarative alternative.

Prefer nixpkgs.

Prefer stable NixOS packages when appropriate.

Use unstable selectively where newer versions are genuinely required.

---

# 18. Verification

Every change should be validated with:

```bash
nix fmt
nix flake check
```

Then evaluate/build the affected configuration.

For system changes:

```bash
sudo nixos-rebuild switch --flake .#nixos --accept-flake-config
```

For development environments:

```bash
devenv test
```

and:

```bash
direnv allow
```

Verify:

```bash
go version
node --version
python --version
rustc --version
java --version
docker --version
devenv --version
direnv version
git --version
```

Do not rebuild the entire system unnecessarily during development.

---

# 19. Guiding principle

The workstation should feel like one coherent developer machine.

```text
NixOS
   ↓
Home Manager
   ↓
Developer tools + applications
   ↓
devenv
   ↓
direnv
   ↓
Project
   ↓
Docker/services
```

The machine is reproducible.

The projects are reproducible.

Company repositories remain untouched until approval.

The existing `niri-desktop` repository remains the only configuration repository.

