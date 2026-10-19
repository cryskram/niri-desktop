# Learnings — Journal for niri-desktop + Pi

Reverse chronological. Newest on top. Each entry is 2-4 lines of durable signal. See `SKILL.md` for the entry template and when to read/write.

## 2026-10-19 — Google Workspace as an extension, not an MCP server (decision) — `pi/google`

- What: `pi/extensions/google-workspace/` — `/google` adds Google accounts the way `/login` picks a provider (each sign-in gets its own record; `prompt=select_account`, and Google's `hd` claim marks Workspace-managed accounts), and 13 tools (Sheets/Docs/Drive + a `google_api` escape hatch for Gmail/Calendar/Tasks) run with the selected account's token; every tool takes an optional `account`. Credentials live at `$PI_CODING_AGENT_DIR/google/{client,accounts}.json` (dir 0700, files 0600), never in the repo. Guide: `docs/google-workspace.md`.
- Why/Context: Vageesh explicitly wanted account selection like a login provider plus "sheets or anything", not one fixed credential set — which rules out both MCP routes (Google's dev-preview `*mcp.googleapis.com` servers, and workspace-mcp's single-user stdio). Google's remote MCP servers also need `access_type=offline` for refresh tokens, and pi's `mcp.json` `oauth` block (1.2.0) has no extra-parameter knob.
- How/Apply: the OAuth client must be a **Desktop app** client in a GCP project with Drive/Sheets/Docs APIs enabled; consent screens left in Testing expire refresh tokens after 7 days (publish, or expect another `/google add`). pi-guard tool rules are exact-name (only path tools are globbed), so renaming a tool in `tools.ts` silently turns it into `"ask"` ⇒ blocked headless — the 13 rules are in `modules/core.nix` and the tool names must match them exactly.
- Test recipe without a model call: `discoverAndLoadExtensions([<store path>], cwd, agentDir)` from pi's `dist/core/extensions/loader.js` under jiti validates registration exactly as pi does (tool names via the `tools` Map keys, definitions under `registered.definition`); `/tmp/gws-check/test.mjs` stubs Google's endpoints (token exchange, Drive/Sheets/Docs) to exercise sign-in, account switching and tool calls offline.

Source: user request 2026-10-19 in a pi session — "let it be an extension, and not an mcp thing… select any of my google accounts".

## 2026-10-19 — Editor stash extension, and how to test a pi TUI extension without tmux (finding) — `pi/ui`

- What: added `pi/extensions/stash.ts` — pi-powerline-footer's editor stash without the footer: `Alt+S` four-state toggle (stash / restore-and-pop / update / nothing), `stash Nl` status key, plus `/stash`, `/stash-history` (Replace/Append/Cancel) and `/stash-clear`. The active stash is a `custom` session entry (`pi.appendEntry`, outside model context, branch-scoped) so `/reload` and resume keep it; recent drafts persist to `$PI_CODING_AGENT_DIR/stash-history.json` (0600, newest-first, deduped, atomic write).
- Why/Context: stash was the one powerline feature worth keeping after reverting to zentui, and powerline itself must not come back (2026-10-10). `pi.registerShortcut` fires only while the *default editor* has focus, so `alt+s` cannot shadow selector keys; not registering `ctrl+s` avoids the built-in-conflict warning entirely.
- How/Apply: TUI extensions are testable without tmux (not installed) — (a) import the factory from the `.ts` with plain Node ≥22 type stripping and drive it with fake `pi`/`ctx` objects (four-state table, branch rebuild on reload, history Replace/Append/Cancel, no-UI safety); (b) drive the real TUI over a Python `pty`, send `\x1bs` for alt+s, and assert on ANSI-stripped output, including `/hotkeys` listing the shortcut.

Source: user asked for "a stashing extension for pi... something similar to what pi-powerline-footer used to offer".

## 2026-10-19 — OpenCode Zen key expired; pi's store had the working one (gotcha) — `system/dms`

- What: the AIOC opencode card went to an error because `~/.local/share/opencode/auth.json` held an old-format `sk-…` key (67 chars). The endpoint answered `401 {"code":"api_key_expired","message":"… Signing in again will not renew this key."}` — so `opencode auth login` is not the fix. `~/.pi/agent/auth.json` already held a current `oc_sk_…` key (51 chars) under both `opencode` and `opencode-go`; copying it across healed the CLI and the card (`source: opencode-usage`).
- Why/Context: OpenCode rotated key formats, and the failure is indistinguishable from a plugin regression until you hit the endpoint directly. Read `source` first: `opencode-api` with a 401 = credentials; `opencode-local` = the env override (`OPENCODE_USAGE_SOURCE=api`) wasn't in the shell you tested from, which is why a manual adapter run can look falsely broken.
- How/Apply: prove it with an authenticated `curl -H "Authorization: Bearer …" https://opencode.ai/zen/go/v1/usage`; then back up and atomically rewrite the auth store (`jq --slurpfile` keeps the key out of argv, mode 600). New keys are minted at https://opencode.ai/console.

Source: user spotted "expecting an updated opencode api key" and asked for a look.

## 2026-10-16 — AIOC quota card: API shape drift, patched adapter, pi card deselected (finding) — `system/dms`

- What: AiOverviewControl 1.21.0 validates the older Zen shape (`rollingUsage`/`usagePercent`/`resetInSec`), but `GET /zen/go/v1/usage` now returns `usage.{rolling,weekly,monthly}.{percent,resetsAt}`, so its opencode card silently degraded to an auth-only note. Fixed by `patches/aioc-opencode-usage-shape.patch` (accepts both shapes) plus `home.activation.patchAiOverviewControlOpencode`, which re-applies it every activation and skips once the file handles the current shape.
- Why/Context: the failure was silent rather than an error, and the plugin's own fixtures/tests still encode the old shape — upstream's suite passes while production breaks. Its `pi` card has no API mode and buckets each session to its start day (under-reporting marathon sessions), so the selection moved to the API-backed `opencode` card that `OPENCODE_USAGE_SOURCE=api` already forces on `dms.service`.
- How/Apply: verified through the plugin's own adapter (`source: opencode-usage`, rolling 8% / weekly 56% / monthly 87%) and its test suite (`tests/test-opencode.sh` passes, so the legacy shape still works); the bar pill matched the live rolling percent while battery (94%) and volume did not. Offer the patch upstream, then drop both the patch and the activation.

Source: user reported the pi card in AI Usage Control "isn't proper" and asked for API-only data.

## 2026-10-16 — Permission gate: pi-guard replaces safety.ts (decision) — `system/pi`

- What: tool calls are gated by third-party `pi-guard` (pinned in `pi/packages.nix`, policy under `settings.guard` in `modules/core.nix`); the repo-local `pi/extensions/safety.ts` is gone — pi-guard covers bash + file paths + MCP, and two gates on one call would double-prompt. Reads stay ungated by request (`read = "allow"`, any file): private keys and `.env` values can therefore reach a transcript, which `/sync` archives — gating the tool was not real protection anyway, since `cat` bypasses it. Writes are denied on the protected set.
- Why/Context: pi-guard matches rules by EXACT tool name and sends any unlisted tool to `ask`, which headless (subagents, `pi -p`) means *blocked*, not prompted — so the rule set enumerates all 31 tools, and a new extension or MCP server needs its tools added. Verified semantics: a rule's first token must equal the command name exactly and only later tokens are globs (`mkfs*`, `*DROP TABLE*`, `shutdown*` are dead rules); `*` never crosses `/` so path values need `**` (`of=*`/`of=**` both miss, hence `dd` denied wholesale); for path-matched tools the catch-all must be `**`; `PI_GUARD` wants a bare rules map (an envelope silently degrades to defaults). Wrapper expansion is genuine: `bash -c 'rm -rf …'` and `find -exec rm` are caught.
- How/Apply: `/guard list` shows effective rules and the prompt UI can save permanent allows (explicit declarative keys still win on merge). Verify in isolation with the raw store binary plus a project `.pi/settings.json`: the HM wrapper's `-e` args (i.e. an older safety.ts) load even with `--no-extensions` and mask pi-guard's decisions.

Source: user asked whether to set up pi-permissions, then chose a full tool allowlist after measurement.


## 2026-10-16 — Link every project in reconstructed activity logs (workflow) — `tracker/evidence`

- What: Dated activity logs reconstructed from GitHub should link every project repository with activity on each date, not just a representative repo.
- Why/Context: Cross-project work is easy to hide behind one sample link; a dated evidence index makes each repo verifiable.
- How/Apply: Keep one per-date/per-repository URL row in an evidence index and link the daily summary to that date's complete list.

Source: User correction while refining Daily Task Tracker.

## 2026-10-16 — SSH in: sshd (key-only) + Tailscale SSH (decision) — `system/ssh`

- What: `modules/ssh.nix` enables OpenSSH key-only (`PasswordAuthentication`/`KbdInteractiveAuthentication` false, `PermitRootLogin` "no", `openFirewall = false` → port 22 stays off the LAN) with an empty `users.users.vageesh.openssh.authorizedKeys.keys` slot; `modules/tailscale.nix` adds `"--ssh"` to `extraSetFlags`.
- Why/Context: `--ssh` makes tailscaled claim **tailnet** port 22 in userspace (gVisor netstack, after WireGuard decryption), so those packets never reach the kernel — sshd cannot serve tailnet clients and tailnet logins are ACL/identity-based instead. NixOS's openssh defaults are password auth **on** (both password and keyboard-interactive), so key-only requires disabling both explicitly. The failure text identifies the responder: `permission denied (tailscale)` = Tailscale SSH needing an ACL rule, `(publickey)` = OpenSSH, `connection refused` = nobody.
- How/Apply: tailnet SSH needs the console policy rule (`src autogroup:member`, `dst autogroup:self`, `users autogroup:nonroot`); key-based tailnet SSH means dropping `--ssh`; LAN sshd means `openFirewall = true`. sshd authorises nobody until keys are added, so the tailnet path is the working one out of the box.

Source: user request "enable ssh connections to this machine" (chose "Both").

## 2026-10-16 — Gotcha: staging for `flake check` leaks into the next commit — `workflow`

- Twice in one session, `git add <newfile>` done *only* so `nix flake check` could see an untracked file left it in the index, so the next `git commit` absorbed it into the wrong commit (and a follow-up commit then found "nothing to commit").
- How/Apply: stage for validation, then `git reset` (mixed — keeps the worktree) before composing the real commits; after each commit verify with `git show --stat` instead of trusting the message. Splitting a published commit needs an authorised `--force-with-lease`; verify the regroup with `git diff --quiet <old> HEAD` (tree must be identical).

Source: icon/Tailscale installs earlier the same day.

## 2026-10-16 — Tailscale in the chooser + guide (decision) — `system/net`

- What: `vpn-toggle` gained a `tailscale` option (up/down through the CLI; no sudo thanks to `--operator`) and `vpn-status` reports its state; `docs/tailscale.md` documents setup, usage, NixOS specifics and the wg0/Proton interaction.
- Why/Context: DMS's VPN widget lists **NetworkManager connections only** (`nmcli`), and Tailscale is not NM-managed, so the fuzzel chooser is Tailscale's only integration point. Tunnels that *can* be imported (`nmcli connection import type wireguard file …`) do appear in the DMS widget.
- How/Apply: `vpn-toggle tailscale` or "tailscale (mesh VPN)" from `Mod+Shift+N`; state from `tailscale status --json | jq -r .BackendState` (Running/Stopped/NeedsLogin — NeedsLogin requires an interactive `sudo tailscale up`, so the toggle reports it rather than hanging).

Source: user request to add Tailscale to the chooser and commit the guide.

## 2026-10-16 — Tailscale added (decision) — `system/net`

- What: `modules/tailscale.nix` — `enable` + `openFirewall` (UDP 41641, direct peer connections instead of DERP) + `useRoutingFeatures = "client"` (sets `checkReversePath = "loose"`) + `extraSetFlags = [ "--operator=vageesh" ]`; `networking.firewall.trustedInterfaces` += `tailscale0`.
- Why/Context: the module does **not** trust `tailscale0`, so tailnet peers could not reach local services (SSH, `tailscale serve`). `loose` rp_filter is required because wg0 and Proton routes coexist here. `--operator` via `extraSetFlags` is applied at boot by `tailscaled-set`, so the CLI needs no sudo and the setting survives rebuilds (a manual `tailscale set` would not).
- How/Apply: login is interactive (`sudo tailscale up`), node key in `/var/lib/tailscale/tailscaled.state` — never in the repo. Flip `useRoutingFeatures` to `"both"` only to advertise an exit node or subnet routes. For unattended auth, `authKeyFile` + `extraUpFlags` drive `tailscaled-autoconnect.service`.

Source: user request "install tela icon theme + tailscale, and guide me through the setup and usage of tailscale".

## 2026-10-16 — Icons: Tela-circle purple replaces Papirus-Dark (decision) — `theme`

- What: `Tela-circle-purple-dark` in `gtk.iconTheme`, dconf and DMS `iconThemeDark`; the name is centralized in `theme/tokens.nix` (`icons.name`); `catppuccin-papirus-folders` (171 MB) dropped from the closure.
- Why/Context: **`tela-circle-icon-theme` 2026-07-07 is broken in nixpkgs for every colourway** — upstream ships 3 dangling symlinks (`xsi-addon-symbolic`, `application-x-addon-symbolic`, `org.xfce.appfinder`) that the `noBrokenSymlinks` fixup hook rejects, so nothing is in the binary cache. Our override prunes broken links in `postInstall` (the check stays enabled); delete it once upstream or nixpkgs fixes it.
- How/Apply: DMS's `settings.json` is app-owned, so the seed migrates only the value it previously wrote (`Papirus-Dark` → Tela) and leaves UI choices alone — `//=` alone never replaces an existing key. Tela supports `colorVariants` (purple, dracula, nord, …) and a `circularFolder` flag via `override`.

Source: user request; chose Tela-circle purple and "activate now" when asked.

## 2026-10-16 — Cost/quota views: AIOC `pi` card + Zen API mode; custom widget retired (decision) — `dms/aioc`

- What: `OPENCODE_USAGE_SOURCE=api` on `dms.service` makes AiOverviewControl's `opencode` card report the OpenCode Go windows (rolling 5 h / weekly / monthly) instead of its default local mode; the repo's own `dms-plugins/opencode-quota/` + `home/opencode-quota-fetch.nix` (widget + 5-min fetcher timer) were deleted, with a one-time activation clearing `~/.cache/opencode-{quota,stats}.json`.
- Why/Context: pi is the driver, so opencode's local DB ($0.65 lifetime, $0.018 on opencode-go) says nothing about real usage. AIOC's `pi` card reads `~/.pi/agent/sessions/**/*.jsonl` locally (no network) — the only truthful source — but it buckets each **whole session to its start day**, so marathon sessions under-report: measured today $0 vs real $0.23, week $6.80 vs real $10.64 ($10.64 = by-message-date sum). Cold scan of 242 MB of sessions costs ~7 s of jq CPU per 120 s cache window.
- How/Apply: costs → AIOC `pi` card (list-price dollars, not the $10/mo plan); quota → AIOC `opencode` card in api mode, since the quota % is the real constraint. Credentials differ per plugin: AIOC accepts `."opencode".key` in opencode's `auth.json` (present); `aiQuotas` wants `."opencode-go"` + an `opencode.db` `credential` row (0 rows) → `not_authenticated`. Endpoint shape: `usage.{rolling,weekly,monthly}.{status,percent,resetsAt}`. Verified 2026-10-16: rolling 2%, weekly 52%, **monthly 85%** (resets Oct 21).

Source: user asked which provider to use for costs in the new AiOverviewControl DMS plugin.

## 2026-10-16 — Input diagnostics installed + `input` group membership (decision) — `system/input`

- What: `environment.systemPackages` gained `libinput` (1.31.3; the CLI is in the package's `bin` output), `evtest` 1.36 and `wev` 1.1.0; `users.users.vageesh.extraGroups` gained `input`.
- Why/Context: niri links libinput as a *library*, so the box had no CLI to inspect input devices. `/dev/input/event*` are `root:input 0660` and the NixOS-provided `input` group already exists (gid 174, declared in the evaluated config), so membership removes the need for `sudo` — at the cost of read access to every keystroke device (keylogging-capable for anything running as the user). A stricter alternative if ever wanted: `services.udev.extraRules` with `TAG+="uaccess"`, which grants the *active session* only.
- How/Apply: `libinput list-devices | debug-events | measure <feature> | record`, `evtest`, `wev` (Wayland events). Group changes need a fresh login — running processes keep their old group list; `newgrp input` fixes a single shell. Deliberately skipped `libinput-gestures` (niri owns gestures) and `services.libinput.enable` (an X11 concern).

Source: user request "install libinput and its tools", then "need to add myself to the input group".

## 2026-10-16 — pi-cache-optimizer + pi-session-search removed (decision) — `pi/ext`

- What: Both pins deleted (`pi/packages.nix`), unwired (`modules/core.nix` extensions + the `session-history` skill), dropped from `scripts/update-pi-extensions.py` (entries + anchors) and the README list; one-time activation removes the orphaned state (`~/.pi/session-search` = 11M FTS index, cache-optimizer shards + config).
- Why/Context: cache-optimizer's footer showed `DS cache 0/0·0M/0M 0.0%` while pi's session log recorded `cacheRead: 224384` for `deepseek-v4.1-flash` — it creates per-model shard entries but never attributes usage through the **`jev/auto` virtual route**, so the status misreported the setup; session-search had no use case (journal + Querion cover recall).
- How/Apply: 6 pins remain (pi-btw, zentui, pi-subagents, pi-web-access, rpiv-ask-user-question, rpiv-todo); `update-pi-extensions.py --check` = 6/6 ok. Beware: virtual-model routing breaks per-model extension attribution — prefer status extensions that read pi's own footer/metadata.

Source: user request after asking what the cache footer meant.

## 2026-10-15 — Icons: Papirus-Dark + Macchiato folders; catppuccin HM module is NOT imported (decision) — `theme/icons`

- What: `home/theme.nix` uses `pkgs.catppuccin-papirus-folders.override { flavor = "macchiato"; accent = "mauve"; }` (name stays `Papirus-Dark`) plus `dconf.settings."org/gnome/desktop/interface"."icon-theme"` — HM's gtk module only writes gtk-2.0/gtk-3.0 settings.ini, GTK4/libadwaita read dconf. Verified: folder.svg fill becomes `#C6A0F6` (mauve), all three sampled icons differ from stock.
- Why/Context: the repo had declared stock `papirus-icon-theme`, so folders were Papirus blue/yellow. **Open finding:** `catppuccin.*` is missing from the HM config — the catppuccin/nix HM module is never imported (only `catppuccin.nixosModules.catppuccin` in flake.nix), so `catppuccin.gtk.icon` and friends do not exist and app theming stays hand-wired via `theme/tokens.nix`. Importing it + `autoEnable` would restyle many apps and could fight those tokens.
- How/Apply: DMS's own icon setting is the app-owned `iconThemeDark` in `~/.config/DankMaterialShell/settings.json`; the activation in `modules/dms-shell.nix` fills it only when absent (jq `//=`), so UI choices are never clobbered.

Source: user request "install and setup some good icon theme".

## 2026-10-15 — Never add niri blur layer-rules for DMS (gotcha) — `niri/dms`

- What: DMS implements `ext-bg-effect-v1` and requests blur for its own surfaces (bar, popouts, modals, notif) — toggle at Settings → Personalization → Theme & Colors. A `dms:*` layer-rule blur therefore double-applies and niri blurs the whole surface *rectangle*, showing a blurred/tinted box around rounded popouts.
- Why/Context: Compositor-side layer-rule blur is only the right tool on compositors *without* the protocol (Hyprland). niri has it, so the rule is redundant and visibly wrong.
- How/Apply: Keep layer-rule blur for non-DMS surfaces only (this repo: the fuzzel fallback launcher). If DMS surfaces look unblurred, fix it in DMS settings, not in niri.

Source: user report 2026-10-15 — blurred, tinted boxes around every bar popout right after the DMS switch.

## 2026-10-15 — Shell switched: Noctalia → DankMaterialShell 1.6 (decision) — `niri/dms`

- What: `modules/dms-shell.nix` enables `programs.dms-shell` (package + quickshell overlaid from nixpkgs-unstable = 1.6.3, since stable 26.05 only has 1.4.x); the `noctalia` flake input, `home/noctalia.nix`, `noctalia-plugins/` and `theme/noctalia-macchiato.json` are gone; keybinds became `dms ipc call spotlight|clipboard|control-center|powermenu|lock`, screenshots `dms screenshot [region|full]`; idle/sleep lock uses DMS's lock with swaylock fallback; swaybg + its niri spawn were removed (DMS owns wallpaper).
- Why/Context: this deleted the last expensive flake input (noctalia always source-built ~15 min) and brought the 1.6 island bar + a QML plugin API. Cost preview: 430 MiB fetch / 1.4 GiB unpacked, nothing heavy built locally (qt/kirigami/quickshell all cached).
- How/Apply: **declarative boundary changed** — `~/.config/DankMaterialShell/settings.json` (bar layout, widget choices, theme selection) is app-owned and rewritten by the DMS UI, so it is deliberately not an HM symlink; the module only seeds it once (don't-clobber). Repo owns the theme (`theme/dms-macchiato.json`), plugins (`dms-plugins/` via `programs.dms-shell.plugins` → `/etc/xdg/quickshell/dms-plugins/`) and `DMS_DISABLE_MATUGEN=1` so the static palette wins and compositor config is never templated. See `docs/decisions/dank-material-shell.md`.

Source: user chose "full switch on main" + unstable 1.6.3 after the DMS exploration.

## 2026-10-15 — Huge pi sessions + zentui animation = 100% CPU and lag (gotcha) — `pi/perf`

- What: A run in the 17MB / ~3k-message session emits ~2.2MB of ANSI and pegs pi at ~102-109% CPU; the same run in a fresh session emits 64KB and costs 0-12%. Per-frame cost scales with transcript size, and zentui's working line re-renders ~16x/s (`textIntervalMs: 60` + `spinnerIntervalMs: 100`).
- Why/Context: The flood goes pi -> herdr (PTY proxy) -> ghostty, so the lag is felt worst inside herdr; idle is fine (1-3%), `--tui-mode regular` does not help, and `/compact` does not shrink the stored transcript (the 17MB session sits at 35% context and stays expensive).
- How/Apply: Work in fresh sessions (biggest win); close unused herdr panes (7 resident pi + 7 veridb MCP children cost 2-10% each while idle); if a big session is unavoidable, slow `/zentui` Working-line intervals. Note zentui rewrites `~/.pi/agent/zentui.json` on exit, so a test instance can clobber hand edits.

Source: user report of laggy pi in herdr/ghostty; measured by A/B runs with `script -qc` and /proc CPU sampling.

## 2026-10-15 — Added pi-cache-optimizer + pi-session-search (decision) — `pi/ext`

- What: Both pinned as zero-dep `plain` derivations in `pi/packages.nix`, wired in `modules/core.nix`, registered in `scripts/update-pi-extensions.py` (`deps: False` + anchors).
- Why/Context: cache-optimizer raises provider prompt/KV cache hit rates (cost + speed) and exposes `Symbol.for("pi.routing.registry.v1")` / `"pi.cache.hints.v1"` that jev-router could opt into; session-search adds FTS5 search over past sessions (`node:sqlite` FTS5 → needs Node 22.19+).
- How/Apply: session-search ships `skills/session-history` and it is listed explicitly in `skills = [...]` — a local store path drops a package's skills manifest, the same reason pi-btw's skill is listed.

Source: user "add both of them" after the plugin shortlist review.

## 2026-10-14 — Todo overlay collapses on ALT+T (preference) — `pi/todo`

- What: rpiv-todo `collapseKey` is `alt+t`, declared via `xdg.configFile."rpiv-todo/config.json"` in `modules/core.nix`.
- Why/Context: Default `ctrl+shift+t` is awkward; ALT+T toggles the panel. Rebind needs pi `/reload` (binding resolves at extension load).
- How/Apply: Edit `collapseKey` in `modules/core.nix`; extension reads `~/.config/rpiv-todo/config.json`, never writes it.

Source: user request 2026-10-14 — custom shortcut to hide the todo panel.

## 2026-10-14 — Terse comments only (preference) — `code/style`

- What: No long/explanatory comment blocks in code, scripts, ansible, or docs; one-liners only where load-bearing, otherwise delete.
- Why/Context: User correction 2026-10-14 on the RBAC branch (cut ~110 lines); applies henceforth to all repos.

Source: user instruction 2026-10-14 — "remember to not have them henceforth".

## 2026-10-13 — OPEN: cut VM builds off prod CMS onto per-stack strapi (decision) — `phoenix/strapi`

- What: Builds still read prod `cms.bondscanner.com` (local `.env` re-pinned there 2026-10-13); cutover needs, per stack: seeded content (`masterclass-landing-page` 404s on s1/s2), public/API permissions (401s), endpoint+token swap in build env, and the `masterclass/index.tsx` null-guard so CMS flakes never red a build again.
- Why/Context: Same-CMS/same-VM means s1-green-s2-red is timing luck on prod's transient non-200s, not a stack difference; `fetchWithRetry` only retries exceptions, never non-200 bodies. One shared CMS can serve all stacks (token travels with endpoint); per-stack CMS needs per-CMS tokens. Tokens/admins live in DB: stage records ride dumps (admin `strapi@bondscanner.com` done on s1 id 12 + stage), `vm-builds` read-only token minted on s1 id 15 and row-copied to s2.
- How/Apply: s1 admin `https://s1-strapi.one.phoenix.sustvest.in/admin` (creds with Vageesh, stage-only); `proxy: {koa:true}` required in `bond-scanner-cms/config/server.ts` behind Traefik (container `dist/` hot-patched, needs committing); prod `vm-builds` replacement = one Unlimited Read-only token on prod for all stacks.

Source: user instruction 2026-10-13 — "remember this as a open issue".

## 2026-10-13 — Querion auto-sync: agent_end, quiet, per-session guard (decision) — `pi/ext`

- What: `/sync` auto-runs on pi's `agent_end` (per prompt completion, not per-turn `turn_end`); fire-and-forget with per-session in-flight+trailing flags, status-key flash only, failures silent.
- Why/Context: A slow first upload must never block the next prompt; quiet failures keep a dead server from nagging mid-flow. Off via `/sync auto off`, `QUERION_AUTOSYNC=0`, or config `autoSync:false`.
- How/Apply: `~/Projects/querion/pi/querion-sync.ts` is upstream, vendored to `~/niri-desktop/pi/extensions/`; verify with a mock `pi.on`/`registerCommand` harness before claiming it works.

Source: user request for sync-on-completion + faster uploads; validated against pi 1.0.4 extension types.

## 2026-10-13 — dummy MCP harness removed; MCP surface is now veridb only (decision) — `pi/mcp`

- What: Deleted the learning harness everywhere — `mcpServers.dummy` in `modules/core.nix`, the `dummy-mcp` derivation in `pi/packages.nix`, and the whole `pi/mcp-servers/` tree (its `node_modules` is untracked, so `git rm -r` leaves it behind and the dir still needs an `rm -r`).
- Why/Context: It existed to learn how pi MCP works; that purpose is served and the one-liner scaffold only added noise to `mcp.json` and the footer.
- How/Apply: `~/.pi/agent/mcp.json` now declares just `veridb` (absolute binary path, creds in veridb's own `.env`). `~/.pi/agent/mcp-cache.json` still lists stale servers (chrome-devtools, parallel-search, deepwiki, dummy) — it is derived state pi ignores/regenerates, not config; only `pi mcp list` reports truth.

Source: user request "remove dummy mcp from this entire setup".

## 2026-10-12 — Committing a cobra fish completion shim is safe (gotcha) — `shell/fish`

- What: `phoenix completion fish` (singular — cobra) emits a ~235-line dynamic shim that calls `phoenix __complete` at completion time and caches per completion; it embeds no command/flag names.
- Why/Context: That makes it safe to commit in this public repo (no internal CLI surface leaks) and it does not go stale as the CLI grows — only cobra's template changes force a regen.
- How/Apply: `phoenix completion fish > home/fish/completions/phoenix.fish`, wired via `xdg.configFile."fish/completions/phoenix.fish".source` in `home/shell.nix`. Verify live with `fish -c 'source <file>; complete -C "phoenix "'`.

Source: user request to wire up phoenix completions; verified the shim delegates rather than hardcodes.

## 2026-10-12 — New files need `git add` before `nix flake check` (gotcha) — `nix/flake`

- What: A flake only sees git-tracked files: `nix flake check` fails with "path … is not tracked by Git" until the new file is `git add`ed.
- Why/Context: Bit the phoenix completion file — the path existed on disk but was invisible to evaluation.
- How/Apply: `git add <newfile>` before any eval/check of a fresh path (already the repo convention for new modules).

Source: flake check error during the phoenix completions wiring.

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
