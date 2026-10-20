# Decision: MCP Through pi-mcp-adapter, Not Pi's Built-in MCP

**Date:** 2026-10-20
**Status:** Accepted (reverses `c7e2e78`, which moved to native and dropped the adapter)

## Context
Pi 0.99+ speaks MCP natively: `~/.pi/agent/mcp.json`, `.pi/mcp.json`, and the
`pi mcp add`/`list`/`login` commands. That is why the adapter was removed in
`c7e2e78`. Two built-in behaviours then turned out to be the wrong defaults
here:

1. **Every enabled server starts with every session** and stays running until
   the session ends, whether used or not — RAM and process slots for nothing.
2. **Every MCP call runs as a `codemode` script**, so a single veridb lookup
   pays the script scaffolding as well as the round trip.

It also has no MCP prompts as slash commands, no elicitation/sampling, no
Tasks, no interactive MCP UI, and its tool search is word-based only.

## Decision
`pi-mcp-adapter` (5.4.0, pinned in `pi/packages.nix`, wired in
`modules/core.nix`) owns MCP. The built-in is disabled declaratively with
`settings.extensions = [ "-builtin:mcp" ]`.

- One `mcp` proxy tool (~200 tokens) instead of one tool per MCP tool.
- Servers connect on first use and stop after 10 idle minutes, reconnecting on
  the next call.
- It reads the same `mcp.json` files, so no server declaration moved and
  `pi mcp add` / `pi mcp list` keep operating on `~/.pi/agent/mcp.json`.
- OAuth tokens go to the OS keychain rather than a plaintext file under
  `~/.pi/agent`.

## Tradeoffs
- pi-guard sees MCP as the single `mcp` tool, not one name per MCP tool.
  Per-tool caution now belongs to the adapter's own `approveTools` /
  `directTools`; the `mcp__veridb__*` allowlist entries are gone. This is a
  deliberate one-time cost: the guard policy is now server-agnostic, so adding
  MCP servers never touches it again.
- **Subagents cannot use MCP from the foreground.** pi-subagents foreground
  children are sessions inside the parent process and never load the parent's
  ambient extensions, so the adapter (and `mcp`) is simply absent. A child that
  needs MCP must set `async: true` (background children load ambient extensions)
  and list `mcp` in `tools`, or use `tools: "inherit"`. Foreground children get
  the parent's registered *providers* only, which is why model routing still
  works there.
- One more npm FOD (registry `node_modules`, ~490 lockfile entries) instead of
  leaning on pi's bundled MCP.
- On first start the adapter appends `-builtin:mcp` to `settings.json` itself.
  Declaring it here keeps that file declarative (it is a store symlink) and
  silences pi's "built-in MCP was not loaded" warning.
- The custom MCP panel (`pi/extensions/mcp-panel`, `/mcpx`, plus its footer
  `mcp` status key) was removed on 2026-10-20. It existed to observe the
  built-in MCP's native state; the adapter's own `/mcp` panel does the same job
  and `/mcp-adapter tools` lists tools, so the homegrown panel was pure
  maintenance.

## Considered and rejected: pi-background-tasks
`pi-background-tasks` (2.6.10) was evaluated on 2026-10-20 for the "subagent
can't reach MCP" problem and rejected — it does not address it. Its
`bg_delegate` children are inspect-only by construction (read/grep/find/ls, no
shell, writes or network) and run with ambient extensions isolated by default,
so MCP stays unreachable there regardless. `bg_run_pi_attested` does spawn a
real `pi --mode json` child with normal discovery, but it is a one-shot
prompt-to-report task, not steerable delegation.

`async: true` on pi-subagents is the supported answer and costs nothing. The
package would also add 11 tools (each needing a pi-guard rule), an
Anthropic-attribution lane this setup does not use, a `Shift+Down` dock
binding, and Fusion runs that spawn three candidates plus an evaluator and a
merger for every call. If a shell-job manager is ever wanted, the documented
fallback is `PI_BG_FEATURES=process`: `bg_run` / `bg_kill` / `bg_logs` /
`bg_status` plus the footer dock, with no delegation or Fusion surface.
