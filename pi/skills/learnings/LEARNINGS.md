# Learnings — Journal for niri-desktop + Pi

Reverse chronological. Newest on top. Each entry is 2-4 lines of durable signal. See `SKILL.md` for the entry template and when to read/write.

## 2026-10-12 — Unstable overlay must `import` (not `.legacyPackages`) for unfree (gotcha) — `nix/flake`

- What: `nixpkgs-unstable.legacyPackages.${system}.pkg` carries nixpkgs' own default config, so an unfree package (`claude-code`) fails evaluation with "Refusing to evaluate package … because it has an unfree license" even though `configuration.nix` sets `allowUnfree = true`.
- Why/Context: The refusal happens in the *unstable* instance during HM's man-db/manpage evaluation, so a bare `nix flake check` fails for a package that looks correctly allowed.
- How/Apply: `modules/core.nix` overlay now does `import nixpkgs-unstable { system = prev.stdenv.hostPlatform.system; config = prev.config; }` once and picks `opencode/pi-coding-agent/herdr/claude-code` from it — identical derivations for the free ones, unfree works.

Source: claude-code install (unfree) broke `nix flake check`; fixed in the same commit.

## 2026-10-12 — claude-code is installed by HM's `programs.claude-code` (decision) — `dev/claude`

- What: `home/development.nix` sets `programs.claude-code.enable = true` (Home Manager 26.05 ships the module); the overlay provides 2.1.292 from unstable instead of stable 26.05's 2.1.223.
- Why/Context: The module installs the package *and* can own `~/.claude` declaratively (settings, context, skills, agents, commands, rules, hooks, lspServers, mcpServers, plugins, marketplaces).
- How/Apply: `settings` is deliberately unset so `~/.claude` stays writable for `claude /login` and manual tuning; adding any managed option makes those files read-only store symlinks, so only put things in git that should be frozen.

Source: user request "install claude-code on this machine".

## 2026-10-12 — Pi wrapper failed loading MCP panel in benchmark (gotcha) — `pi/mcp`

- What: A benchmark launch through the Nix `pi` wrapper exited before a model request because `mcp-panel/index.ts` could not import `./panel.ts`.
- Why/Context: This is separate from Relith/model behavior; the targeted replay worked with the raw Pi binary and built-in MCP only.
- How: Repair the wrapper's MCP-panel package before relying on normal launches; the raw binary was only a local test workaround.

Source: Querion/Relith Task 3 replay on 2026-10-12.

## 2026-10-12 — Control allowlists must omit Relith tool names (gotcha) — `relith/pi`

- What: A disabled Relith project entry did not reliably prevent tool calls when `mcp__relith__*` names remained in the control `--tools` list.
- Why/Context: The Pi runtime can retain system/global tool declarations independently of a project `enabled:false` override.
- How: Use a root-confined read-only workspace MCP in both arms; control allowlists only workspace tools, while treatment adds Relith tools, then inspect JSONL calls.

Source: post-FTS Task 3 replay; control Relith calls invalidated that pair.

## 2026-10-12 — Home-Manager Pi wrapper failed MCP panel load (gotcha) — `pi/mcp`

- What: A benchmark launch through the Nix `pi` wrapper exited before a model call because its `mcp-panel` extension entrypoint could not import `./panel.ts`.
- Why/Context: The failed startup isn't an API/model failure; later isolated testing used the raw Pi binary with built-in MCP only.
- How: Fix the Nix extension package before relying on the wrapper again; use the raw binary only as a temporary, explicitly reported test workaround.

Source: Querion cross-project Task 3 retry on 2026-10-12.

## 2026-10-12 — Omit Relith names from the disabled control allowlist (gotcha) — `pi/mcp`

- What: A control with `relith.enabled=false` still emitted Relith tool calls when its `--tools` allowlist explicitly included `mcp__relith__*` names.
- Why/Context: Server toggles alone are not a reliable per-run tool boundary in every Pi launch context.
- How: Control allowlists should contain only the rooted workspace tools; treatment adds Relith tool names, then verify JSONL call events.

Source: Task 3 provenance replay in the Querion/Relith benchmark.

## 2026-10-12 — `/mcpx` now owns the MCP footer + panel (decision) — `pi/mcp`

- What: `pi/extensions/mcp-panel/` (index/panel/state.ts) serves the footer `mcp` key (`● dummy(3)·○ veridb`, disabled hidden, 2s poll + events) and the `/mcpx` adapter-style panel; `mcp-status.ts` removed from `core.nix`.
- Why/Context: builtin MCP is `replaceable` — any extension registering `/mcp` unloads it (resource-loader `omitReplacedExtensions`), so the panel observes native state (config + `pi.getAllTools()` namespaces) and applies toggles via config write + `ctx.reload()` (reload re-emits `session_start`).
- How/Apply: edit `pi/extensions/mcp-panel/*.ts`, keep strict `tsc --noEmit` clean; a read-only global mcp.json (HM store symlink) falls back to a project override automatically.

Source: footer staleness report + "recreate the pi-mcp-adapter UI" request; verified with pty-driven TUI tests (panel keys, toggle→reload→footer update).

## 2026-10-11 — Make Relith search ergonomic before claiming token savings (gotcha) — `relith/search`

- What: Cross-repo tests exposed case-sensitive repo filters, lowercase `and` being parsed as FTS syntax, and unbounded trace graph edges bloating responses.
- Why/Context: These failures increase retries and context size, obscuring any actual retrieval benefit.
- How: Resolve unique repo names case-insensitively, reserve uppercase boolean words for explicit FTS, and cap trace edges relative to `max_results`.

Source: Querion/VeriDB retrieval optimization (`7df9c12`).

## 2026-10-11 — pi `/mcp` cannot save global toggles (gotcha) — `pi/mcp` + `nix/home-manager`

- What: `~/.pi/agent/mcp.json` is a home-manager `home.file` symlink into `/nix/store` (ro), so `/mcp` Disable/Exposure on a global server fails with EACCES ("Could not update …"); same for `pi mcp add/remove`.
- Why/Context: pi saves to the file that defines the server — any store-symlinked config path is unwritable, so global state must change in `modules/core.nix`.
- How/Apply: Per-project `/mcp` → "Disable in this project" (writes `<cwd>/.pi/mcp.json`), one-run `pi --no-mcp` / `--exclude-tools 'mcp__X__*'`, or edit core.nix + rebuild.

Source: user report 2026-10-11; write test on the symlink + `dist/extensions/mcp/config.js` save path.

## 2026-10-11 — Restrict tools to isolate cross-repo Relith tests (workflow) — `relith/pi`

- What: Identical Querion excerpts plus an allowlist containing only direct Relith search/read tools produced a clean control/treatment pair; treatment called Relith, while the disabled control had no callable tools.
- Why/Context: `enabled: false` and prompt instructions alone do not stop a shell-capable agent from launching the local MCP binary.
- How: For retrieval-isolation tests, omit shell/filesystem/codemode tools and provide the same current-repo excerpts to both arms.

Source: Querion/VeriDB restricted-tool pair; protocol recorded in `docs/pi-evaluation.md`.

## 2026-10-11 — Disabled MCP is not a filesystem sandbox (gotcha) — `relith/pi`

- What: A Pi control with Relith disabled used Bash to launch the local `relithmcp` binary through hand-built stdio JSON-RPC, bypassing the tool gate.
- Why/Context: An MCP toggle prevents normal tool registration, but not direct access to local binaries or indexed sibling repositories.
- How: Isolate the control filesystem and audit tool arguments/results before scoring with/without runs.

Source: Querion/VeriDB cross-project pilot; protocol guard added to `docs/pi-evaluation.md`.

## 2026-10-10 — Direct MCP exposure still may not be used (gotcha) — `relith/pi`

- What: In a three-task Pi pilot, six directly exposed Relith tools still received zero calls; both arms scored 18/18 on the answer rubric.
- Why/Context: Tool availability is not tool adoption, and token deltas without retrieval are not a Relith efficacy result.
- How: Track actual MCP invocations and treat direct-schema overhead separately from retrieval quality/cost.

Source: matched direct-exposure benchmark, `docs/pi-evaluation.md`.

## 2026-10-10 — Relith pilot: availability is not usage (gotcha) — `relith/pi`

- What: Pi's first deferred-MCP pilot invoked no Relith tools across three code tasks; it also exposed an `IndexFile` metadata fast path that could override a changed-content hash when mtime/size matched.
- Why/Context: MCP connectivity alone does not prove retrieval benefit, and event-driven indexing must trust content hashes over metadata.
- How: Expose a small core tool set directly and count actual MCP calls; event-triggered indexing bypasses the mtime fast path.

Source: v0.8 Pi pilot and regression fix (`3187c8c`).

## 2026-10-10 — Relith v0.8 builds trust before semantic search (decision) — `relith/roadmap`

- What: v0.8 prioritizes index correctness, explicit shared notes, and a Pi with/without Relith usage comparison; v0.9 starts semantic retrieval.
- Why/Context: User selected the phased scope and asked for regular focused commits.
- How: Compare matched Pi tasks, model/settings, quality, flow, and token usage before claiming a win.

Source: User direction during Relith implementation planning.

## 2026-10-10 — Relith's north star is shared agent context (decision) — `relith/product`

- What: Relith's stated purpose is to give different coding agents a common context space, implemented in Go.
- Why/Context: This is the product lens for deciding whether future scope/features belong.
- How: Distinguish shared indexed code context from durable cross-session/agent memory.

Source: User clarification during Relith product review.

## 2026-10-10 — Pi footer: zentui, not powerline (preference) — `pi/ui`

- What: The Pi footer flipped zentui → pi-powerline (1aab21b) → zentui 0.30.0 (c68ba0f); current state is zentui with powerline's settings/vibes fully removed.
- Why/Context: Powerline's vibe/queue/CD feature set didn't stick; zentui's opencode-style TUI footer is the wanted feel. Powerline-only config (`powerline.*`, `workingVibe*`, vibes file) must not be reintroduced without asking.
- How: Edit `pi/packages.nix` zentui block + `modules/core.nix` extensions; keep `jev-router.ts` (routing is footer-agnostic, its `jev-route` status key is just ignored by zentui).

Source: user instruction "revert back to zentui. remove powerline" after powerline era.

## 2026-10-10 — Sustain humor beyond a one-liner (preference) — `pi/tone`

- What: Pi should carry its playful, funny voice through substantive responses instead of spending the whole humor budget on one opening line.
- Why/Context: User says Pi remains too restrained despite explicitly requesting humor.
- How/Apply: Weave several relevant comic beats through relaxed explanations; ease off for serious, stressed, or tiny exchanges.

Source: User correction — asked to increase Pi's humor.

## 2026-10-10 — Git flakes exclude untracked source files (gotcha) — `nix/flake`

- What: Flake evaluations cannot import newly created Git source paths until Git tracks them, even when they exist on disk.
- Why/Context: The first `nix flake check` rejected the new `pi/brain/AGENTS.md` as untracked.
- How/Apply: Stage new source files normally, or use `git add -N -- <paths>` for evaluation without staging their contents.

Source: Initial shared-brain validation failed on an untracked Nix path; passed after intent-to-add.

## 2026-10-10 — Pi subagent model docs drifted from config (gotcha) — `pi/subagents`

- What: The root agent manual claimed subagents used `muse-spark-1.2-contributor`, but `modules/core.nix` configures `auto` through jev.
- Why/Context: Stale guidance can override the actual declarative model routing in future sessions.
- How/Apply: Treat `modules/core.nix` as authoritative for live Pi defaults and keep the model summary in `AGENTS.md` aligned.

Source: Compared repository instructions with current `modules/core.nix` during shared-brain setup.

## 2026-10-10 — pi-subagents omit global context by default (gotcha) — `pi/subagents`

- What: Built-in Pi subagents exclude global `AGENTS.md` and discovered skills unless `inheritGlobalContext` and `inheritSkills` are enabled.
- Why/Context: A shared brain is not automatic in pi-subagents 0.73.1 even though repository instructions are inherited.
- How/Apply: Explicitly enable project context, global context, and skills in `modules/core.nix` overrides for every built-in role.

Source: pi-subagents 0.73.1 `docs/agents.md` — default inheritance behavior.

## 2026-10-10 — Layered Pi brain, Pi-wide only (decision) — `pi/brain`

- What: Keep one canonical layered brain shared by Pi sessions and delegated agents; prepare the Vageesh skill as an evidence-only scaffold.
- Why/Context: User chose Pi-only scope and layered docs; other agent products and inferred twin traits are out of scope.
- How/Apply: Maintain global operating guidance, Pi append instructions, project `AGENTS.md`, and durable learnings as distinct sources.

Source: User choices during shared-agent-brain setup.

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

## 2026-10-09 — Nebula webhook fan-out options, no nebula code change (decision) — `phoenix/fleet`

- What: To deliver one inbound webhook (e.g. Cashfree `notify_url` on s1-nebula) to s2/s3 nebulas without editing nebula: Traefik cannot fan-out (1 request → 1 backend). Options ranked: (1) nginx `mirror` tee in front — one stable URL registered with the gateway, proxies to s1-nebula, fire-and-forget mirrors to `https://s2/s3-nebula...` (`mirror_request_body on`; stock nginx module); (2) check gateway dashboard for native multi-URL webhooks first; (3) goreplay for shadow-traffic testing (not delivery). Code ways when infra stops sufficing: forward-after-process via `PEER_NEBULAS` env (~20 lines), or publish raw webhooks to a kafka topic all stacks consume.
- Why: Vageesh wants s1-nebula as the single registered URL with infra-only distribution until worst case; gotchas carried forward: handlers must be idempotent (gateway retries × mirrors multiply), secrets must match across stacks for signature verify, mirrors don't help s1 availability.
- How: Tee container + Traefik route; mirrors to public `https://sX-nebula...` URLs avoid docker-network juggling.

Source: user instruction 2026-10-09 — "remember these options".
