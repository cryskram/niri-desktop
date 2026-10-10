# Learnings — Journal for niri-desktop + Pi

Reverse chronological. Newest on top. Each entry is 2-4 lines of durable signal. See `SKILL.md` for the entry template and when to read/write.

---

## 2026-10-10 — Proton VPN “won't launch” = tray-minimized + wrong binary name (gotcha) — `nix/vpn`

- What: GUI binary is `protonvpn-app` (NOT `proton-vpn` — old script/docs used that name, so `vpn-toggle`'s proton-gui branch was dead code); and `~/.config/Proton/VPN/app-config.json` had `"start_app_minimized": true`, making the app destroy its window ~9ms after creating it — looks like it never opens.
- Why/Context: app keeps running headless in tray; symptom is “I click it and nothing happens” even though `pgrep -f protonvpn-app-wrapped` finds it.
- How/Apply: launch/kill via `protonvpn-app`; flip `start_app_minimized` to `false` (app rewrites this file on exit, so it can't live in the flake). Debug similar cases with `WAYLAND_DEBUG=1` + grep `xdg_toplevel.*destroy()` and `niri msg windows`.

Source: live debug session 2026-10-10 — user asked “why isnt proton vpn launching?”.

## 2026-10-09 — rpiv typebox loader warning → bump to 2.12.0 (gotcha) — `pi/ext`

- What: pi's loader rejects host-bundled packages declared as `dependencies` ("must be in peerDependencies with a '*' range"); rpiv 2.11.0 had `typebox` as a dep, v2.12.0 moved it to peerDeps.
- Why: An installed copy bypasses pi's loader → duplicate runtime modules; warning surfaces as `[Extension issues]` on startup.
- How: `pi/packages.nix` bump `rpivExtension` tag + re-capture npmHash (fakeHash → build → got:). Also: renaming an extension (zentui → pi-powerline) must update `regions_of` anchors in `scripts/update-pi-extensions.py` or `--check` dies with "cannot find anchor".

Source: user reported Extension issues after veridb/trusted-folder wiring; upstream v2.12.0 fixed it.

## 2026-10-09 — pi MCP paths: user `~/.pi/agent/mcp.json`, project `.pi/mcp.json` (gotcha) — `pi/mcp`

- What: pi 0.99 reads user-level MCP servers from `~/.pi/agent/mcp.json` and project servers from `.pi/mcp.json` (`pi mcp add --local`); `~/.config/mcp/mcp.json` is the Claude Code convention, not pi's.
- Why: A veridb README pointed pi users at the wrong file; project config is also ignored until the project is trusted (`pi mcp list` says so).
- How: Validate with `pi mcp list`; keep credential-bearing servers user-level, and note `.pi/` is gitignored in this repo so project entries stay local.

Source: pi mcp.md docs + `pi mcp --help` output during veridb wiring.

---

## 2026-10-08 — Name the platform plan implementation v2 (preference) — `phoenix/docs`

- What: The Phoenix Dev/QA platform plan should be titled and discoverable as “Implementation V2.”
- Why: It is a versioned proposal alongside the current Compose-based implementation, not a generic implementation plan.
- How: Use `docs/implementation-v2.md` and link it from the Phoenix documentation index.

Source: user naming correction.

## 2026-10-08 — Radar's MCP access must be RBAC-scoped (gotcha) — `phoenix/radar`

- What: Skyhook Radar's MCP can expose write operations; MCP client confirmations do not replace Kubernetes RBAC.
- Why: A shared in-cluster UI/MCP endpoint can otherwise inherit broad ServiceAccount access.
- How: Start read-only, keep secrets/exec/Helm writes disabled for general users, and require OIDC/proxy auth if exposed.

Source: `skyhook-io/radar` README and in-cluster/MCP documentation.

## 2026-10-08 — Zot can persist registry blobs in Krutrim object storage (gotcha) — `phoenix/registry`

- What: Zot supports S3-compatible remote storage, and Krutrim documents an S3-compatible object store; endpoint compatibility still needs a push/pull test.
- Why: A registry can recover after VM loss without nightly image exports, but raw bucket-age deletion can remove blobs still referenced by image manifests.
- How: Test Zot's S3 driver, then use Zot retention/GC and protect promoted image digests.

Source: Zot storage/retention docs and Krutrim Object Storage docs.

## 2026-10-08 — Phoenix should mirror production Kubernetes (decision) — `phoenix/k3s`

- What: Dev and QA should use K3s/Helm/Traefik to match the company's AWS Kubernetes/ArgoCD production workflow; Compose is not the target runtime.
- Why: Environment parity is a primary requirement, so Kubernetes familiarity and deployment behavior outweigh minimizing platform components.
- How: Design the dev/QA promotion path around OCI image digests, Helm releases, and K3s while keeping Phoenix as the developer-facing CLI.

Source: user correction — production parity is a project requirement.

## 2026-10-08 — Phoenix needs immutable images for promotion (gotcha) — `phoenix/ci`

- What: Phoenix currently builds on the target VM and does not push to its local registry; QA stacks also share VM-wide Kafka topics despite per-stack DB/Redis.
- Why: Cross-VM promotions need image digests/manifests, and parallel QA stacks need topic isolation to avoid cross-test events.
- How: In `~/Projects/TAP/phoenix`, add registry push-by-digest and release manifests; namespace Kafka topics or broker per QA stack.

Source: inspected Phoenix README, `docs/operations.md`, `docs/architecture.md`, and `docs/backlog.md`.

## 2026-10-07 — This journal is the preference memory (decision) — `pi/skill`

- What: `pi/skills/learnings/LEARNINGS.md` is the single append-only journal for preferences, decisions, and reusable gotchas across all pi agents/sessions.
- Why: Agent memory resets per session; without this file preferences re-learn every time. Rules enforce read-at-start, write-on-learn.
- How: At session start `read` this file; on any new signal `edit` an entry on top. Keep entries 2-4 lines, tagged `category` + `scope/tag`.

Source: bootstrapped with niri-desktop declarative setup — repo is source of truth for pi config.

## 2026-10-07 — Declarative repo is law (decision) — `nix/core`

- What: All system, pi, and HM config lives in `~/niri-desktop` flake (`flake.nix`, `modules/`, `home/`, `pi/`). Never imperatively edit `~/.pi` or running system; change repo → `nix flake check` → `nixos-rebuild dry-build`.
- Why: Rebuilds must reproduce on fresh checkout; imperative drift breaks that.
- How: `pi` is `programs.pi.coding-agent` via `pi.nix` (see `modules/core.nix`); `pi/packages.nix` pins extensions; `AGENTS.md` §2/§9 is the rule.

Source: `AGENTS.md` + `modules/core.nix` + `README.md` Quick start.

## 2026-10-07 — Office skills are external and authoritative (preference) — `pi/skill`

- What: Company skills under `~/Projects/TAP/claude-plugins/...` (backend-coding-practices, backend-to-qa, web-to-qa, mobile-to-qa, generate-test-cases, qa-signoff, schema-reference, query-patterns) are wired via `extraArgs --skill` and stay outside the repo.
- Why: Keep TAP domain authoritative; repo-owned skills are only `repo-understanding` and `learnings`.
- How: Do not move or duplicate TAP skills into `pi/skills/`; `modules/core.nix` `extraArgs` is the interface.

Source: `modules/core.nix` + `.gitignore` + user instruction "retain my office skills".

## 2026-10-07 — Prompts removed in favour of skills (decision) — `pi/prompt`

- What: `pi/prompts/*.md` removed — skills preferred for workflows needing context; prompt templates are thin `/` commands, not skill replacements (see pi docs).
- Why: Skills carry description + on-demand loading; prompts add noise without specialization.
- How: `promptTemplates = [ ../pi/prompts ]` removed from `modules/core.nix`; `pi/prompts/` left empty with `.gitkeep` for future intentional templates.

Source: user decision — "remove any existing prompts" — validated against pi docs `prompt-templates.md` vs `skills.md`.

## 2026-10-07 — Fish + Starship + Catppuccin is interactive shell (preference) — `shell/fish`

- What: Interactive shell is `fish` with `starship`; abbrs (`g`, `gs`, `lg`, `y`, `cat→bat`, `ls→eza -la --icons --git`, `grep→rg`, `find→fd`), `fish_greeting` empty, Catppuccin Macchiato palette.
- Why: `home/shell.nix` is explicit on this; pi should match shell idioms when proposing commands.
- How: `home/shell.nix` `programs.fish.shellAbbrs` + `programs.starship`.

Source: `home/shell.nix`.

## 2026-10-07 — Commit style is conventional, focused (workflow) — `git/commit`

- What: Commit messages are `type(scope): summary` with optional body; diffs are inspected for secrets/accidental changes; commits are focused, never generic "changes"/"final".
- Why: `AGENTS.md` §12 + `pi/prompts/commit.md` legacy (removed but behaviour retained) — matches `git log` style.
- How: `git status`, `git diff`, secrets scan, then propose; wait for explicit confirmation before commit/push.

Source: `AGENTS.md` §12 + repo history.
