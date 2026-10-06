# Decision: pi Module — Stay on lukasl-dev/pi.nix Until Home Manager Ships Native Support

**Date:** 2026-10-06
**Status:** Accepted (migration deferred, trigger defined below)

## Context
`programs.pi.coding-agent` (rules, skills, extensions, themes, prompt
templates, settings) currently comes from the third-party flake
`github:lukasl-dev/pi.nix`, with the binary overlaid from
`nixpkgs-unstable` (`pi-coding-agent` 1.0.2; `pi --version` reports 1.0.0
until the next rebuild). Three "proper" alternatives were investigated on
2026-10-06:

1. **Official upstream `github:earendil-works/pi` flake** — provides
   `packages` (`pi` 1.0.4), `apps`, and `overlays.default` only. **No
   NixOS or Home Manager modules.** Using it means hand-rolling all
   declarative wiring (wrapper script with `--append-system-prompt /
   --skill / --extension / --theme / --prompt-template` flags plus a
   `settings.json` writer). Maximum cumbersome; rejected for now.
2. **Home Manager native `programs.pi-coding-agent`** — exists on HM
   `master` (options: `enable`, `package`, `appendSystem` → writes
   `APPEND_SYSTEM.md`, `context` → `AGENTS.md`, `settings` →
   `settings.json`, `keybindings`, `models`, `extraPackages`,
   `configDir`). Clean and zero-extra-flake. **But our pinned HM
   `release-26.05` does not contain
   `modules/programs/pi-coding-agent.nix`** (verified in the store).
   Adopting it now means bumping Home Manager to `master`, which expects
   unstable nixpkgs and risks churn across the whole desktop. Rejected
   for now.
3. **nixpkgs package only** — `pi-coding-agent` already exists in
   `nixos-26.05`; the unstable overlay is freshness-only. Package
   availability was never the problem; the module is.

## Alternatives Considered
1. **Stay on `lukasl-dev/pi.nix` (chosen)** — the only option that is
   both declarative and compatible with stable pins today. One block in
   `modules/core.nix`, all current wiring (`pi/rules.md`, `pi/skills/`,
   `pi/prompts/`, `pi/themes/`, `pi/packages.nix` extensions, subagent
   defaults, MCP `mcp.json`, Querion config) keeps working unchanged.
2. **Bump HM to master and migrate now** — full-desktop churn for one
   module; HM master + `nixos-26.05` mismatch risk. Not worth it.
3. **Upstream flake + hand-rolled wrapper** — loses `jail`,
   `environment.file/value`, `mkCodingAgent` niceties; every resource
   becomes manual `home.file` + flag plumbing. Most cumbersome.

## Decision
Stay on `lukasl-dev/pi.nix` for the module; keep the `nixpkgs-unstable`
overlay for a fresh binary. Revisit when a pinned Home Manager release
contains `modules/programs/pi-coding-agent.nix`.

**Migration trigger:** `ls $(nix eval --impure --expr
'(builtins.getFlake
"github:nix-community/home-manager/<our-pinned-ref>").outPath')/modules/programs/pi-coding-agent.nix`
succeeds for whatever ref `flake.nix` pins.

**Version status (checked 2026-10-06):** no released Home Manager
version carries the module yet. `release-26.05` predates it (module
first landed on `master` ~June 2026, after the 26.05 branch-off) and
`release-26.11` does not exist as a branch yet. Expect it first in
`release-26.11` (~Nov 2026); until then this decision stands.

## Migration sketch (when triggered)
- `flake.nix`: drop `pi` input (or retarget it at upstream for the
  binary), remove `pi.nixosModules.default` from `modules`,
  remove `extra-substituters`/`extra-trusted-public-keys` entries for
  `pi.cachix.org` (both `nixConfig` and `modules/core.nix`
  `nix.settings`), drop `pi` from `specialArgs` unless still needed.
- `modules/core.nix`: replace the `programs.pi.coding-agent = { … }`
  block (NixOS level, provided by pi.nix) with
  `home-manager.users.vageesh.programs.pi-coding-agent = { … }`:

  | Today (pi.nix) | HM native |
  |---|---|
  | `enable` | `enable` |
  | `package` (unstable `pi-coding-agent`) | `package` (same expression; HM default `pkgs.pi-coding-agent` also fine once 26.05+ carries it) |
  | `rules = ../pi/rules.md` | `appendSystem = ../pi/rules.md` (same semantics: appended, not replacing; filename stays `rules.md`, content lands in `APPEND_SYSTEM.md`) |
  | `settings = { … }` (provider/model/thinking/theme/tools/subagents) | `settings = { … }` (identical dict) |
  | `skills` + `extraArgs --skill` (incl. absolute `~/Projects/TAP/…` paths) | `settings.skills = [ … ]` (settings resource arrays accept absolute and store paths; keep `extraArgs` TAP skills here) and/or `home.file.".pi/agent/skills/…"` symlinks (agent dir auto-discovery) |
  | `extensions` (store paths + `pi/extensions/*.ts`) | `settings.extensions = [ … ]` and/or `home.file.".pi/agent/extensions/…"` |
  | `promptTemplates = [ ../pi/prompts ]` | `settings.prompts` and/or `home.file.".pi/agent/prompts"` |
  | `themes = [ ../pi/themes/….json ]` | `settings.themes` and/or `home.file.".pi/agent/themes"` |
  | (unused: `models`, `jail`, `environment`) | `models`, `keybindings` (new capability — consider managing `keybindings.json` instead of leaving it imperative), `extraPackages` (e.g. `nodejs` for the dummy MCP instead of absolute `${pkgs.nodejs}/bin/node`), `configDir` (leave default) |
- Untouched: `pi/packages.nix` (pure `pkgs`-only, no pi.nix
  dependency), `home.file.".pi/agent/mcp.json"`, Querion
  `xdg.configFile`, `AGENTS.md`/`README.md` references to update
  (`programs.pi.coding-agent` → `programs.pi-coding-agent` under the
  HM user block).
- Validate: `nix flake check`, `nixos-rebuild dry-build --flake
  .#nixos`, diff `~/.pi/agent/{settings.json,APPEND_SYSTEM.md}` before
  vs after, `pi` smoke test + `/reload`.

## Consequences
- **Positive:** No churn today; a one-shot, well-defined migration
  later; no imperative drift in between.
- **Negative:** Third-party input retained until then; upstream binary
  (1.0.4) newer than what we run until nixpkgs-unstable catches up.
- **Follow-up:** Check for the HM module on each flake update cycle
  (`nix flake update home-manager --dry-run` + trigger command above).

## References
- HM module manual (master):
  `https://nix-community.github.io/home-manager/options/home-manager/programs/pi-coding-agent.html`
- pi.nix options (`rules` → `--append-system-prompt`):
  `coding-agent/options.nix` in `github:lukasl-dev/pi.nix`
- Upstream flake (packages only, no modules):
  `github:earendil-works/pi` (`flake.nix`: `packages`, `apps`, `overlays`)
- pi settings/resources docs: `settings.md`, `configuration.md`
  (agent-dir auto-discovery: `extensions/`, `skills/`, `prompts/`, `themes/`)
- AGENTS.md §33 Architecture Decisions
