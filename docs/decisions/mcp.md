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
  `directTools`; the `mcp__veridb__*` allowlist entries are gone.
- One more npm FOD (registry `node_modules`, ~490 lockfile entries) instead of
  leaning on pi's bundled MCP.
- On first start the adapter appends `-builtin:mcp` to `settings.json` itself.
  Declaring it here keeps that file declarative (it is a store symlink) and
  silences pi's "built-in MCP was not loaded" warning.
- `pi/extensions/mcp-panel` (`/mcpx`) still reads native state. It is
  superseded by the adapter's `/mcp` panel and is kept only until the
  workaround cleanup pass.
