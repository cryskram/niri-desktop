/**
 * MCP status — publishes the configured MCP servers as a status key.
 *
 * Reads the same two files pi itself reads:
 *   - user level:    $PI_CODING_AGENT_DIR/mcp.json  (default ~/.pi/agent/mcp.json)
 *   - project level: <cwd>/.pi/mcp.json             (trusted projects only)
 * and publishes `mcp` → `dummy·veridb` via ctx.ui.setStatus at the start of
 * every agent run.
 *
 * Display: zentui shows observed status keys through Extension statuses —
 * run `/zentui extensions` and give the `mcp` key a placement (Left/Middle/
 * Right) instead of Off. This is a *configured* view: pi connects servers
 * lazily on first tool use, so for live health + tool counts run `pi mcp list`.
 *
 * Declarative: loaded via modules/core.nix `programs.pi.coding-agent.extensions`.
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "mcp";

function configuredServers(path: string): string[] {
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8")) as {
      mcpServers?: Record<string, unknown>;
    };
    return Object.keys(parsed.mcpServers ?? {});
  } catch {
    // Absent or unparseable file contributes nothing — never fail the turn.
    return [];
  }
}

function publish(ctx: ExtensionContext): void {
  const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
  const names = [
    ...new Set([
      ...configuredServers(join(agentDir, "mcp.json")),
      ...configuredServers(join(process.cwd(), ".pi", "mcp.json")),
    ]),
  ];
  try {
    // Guarded the same way jev-router guards it: headless modes (print/rpc)
    // have no ctx.ui and must never break.
    (
      ctx as unknown as {
        ui?: { setStatus?: (k: string, v: string | undefined) => void };
      }
    ).ui?.setStatus?.(STATUS_KEY, names.length > 0 ? names.join("·") : undefined);
  } catch {
    // Footer bookkeeping must never fail a run.
  }
}

export default function mcpStatus(pi: ExtensionAPI): void {
  pi.on("agent_start", (_event, ctx) => {
    publish(ctx);
    return undefined;
  });
}
