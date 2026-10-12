/**
 * MCP footer status + `/mcpx` panel — one extension, two surfaces.
 *
 * Footer: publishes the `mcp` status key for zentui's Extension statuses
 * (`/zentui extensions` places it; configured right/zentui in zentui.json).
 * Format is `● dummy(3) · ○ veridb`: ● connected with tool count, ○ configured but
 * not connected, disabled servers hidden entirely. Unlike the old mcp-status.ts
 * (agent_start only, all configured names), this refreshes from a 2s poll plus
 * session/turn/tool events, so a server disabled via /mcp disappears within
 * seconds instead of lingering until the next prompt.
 *
 * Panel: `/mcpx` opens the adapter-style TUI (panel.ts). Reads and writes go
 * through state.ts, which mirrors pi's own mcp.json merge/edit rules.
 *
 * Declarative: loaded via modules/core.nix `programs.pi.coding-agent.extensions`.
 */
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { createMcpPanel, type PanelResult } from "./panel.ts";
import { footerStatus, formatSummary, forgetLiveState, loadServers, type ConfigEnv } from "./state.ts";

const STATUS_KEY = "mcp";
const POLL_MS = 2000;

function configEnv(ctx: ExtensionContext): ConfigEnv {
	const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
	return { agentDir, cwd: ctx.cwd, projectTrusted: ctx.isProjectTrusted() };
}

export default function mcpPanel(pi: ExtensionAPI): void {
	let ctxRef: ExtensionContext | undefined;
	let lastStatus: string | undefined;
	let poll: ReturnType<typeof setInterval> | undefined;

	const publish = (): void => {
		const ctx = ctxRef;
		if (!ctx) return;
		try {
			const env = configEnv(ctx);
			const { servers } = loadServers(env, pi.getMcpServers());
			const status = footerStatus(servers, () => pi.getAllTools());
			if (status !== lastStatus) {
				lastStatus = status;
				ctx.ui.setStatus(STATUS_KEY, status);
			}
		} catch {
			// Stale context (after reload/quit) or headless mode: footer bookkeeping
			// must never fail a run — same guard jev-router uses.
		}
	};

	const stopPoll = (): void => {
		if (poll !== undefined) {
			clearInterval(poll);
			poll = undefined;
		}
	};

	pi.on("session_start", (_event, ctx) => {
		stopPoll();
		ctxRef = ctx;
		forgetLiveState();
		lastStatus = undefined;
		publish();
		if (ctx.mode === "tui") {
			// Connections settle asynchronously after startup; poll (cheap: two small
			// files + a tool scan) so the footer tracks them without a new prompt.
			poll = setInterval(publish, POLL_MS);
			(poll as unknown as { unref?: () => void }).unref?.();
		}
		return undefined;
	});

	pi.on("agent_start", (_event, ctx) => {
		ctxRef = ctx;
		publish();
		return undefined;
	});

	pi.on("turn_end", (_event, ctx) => {
		ctxRef = ctx;
		publish();
		return undefined;
	});

	pi.on("mcp_servers_change", (_event, ctx) => {
		ctxRef = ctx;
		publish();
		return undefined;
	});

	pi.on("session_shutdown", () => {
		stopPoll();
		const ctx = ctxRef;
		try {
			if (ctx && lastStatus !== undefined) ctx.ui.setStatus(STATUS_KEY, undefined);
		} catch {
			// Ignore a context invalidated mid-shutdown.
		}
		lastStatus = undefined;
		ctxRef = undefined;
		return undefined;
	});

	pi.registerCommand("mcpx", {
		description: "MCP panel: status, tools, enable/disable, exposure (native MCP companion)",
		handler: async (_args, ctx) => {
			const env = configEnv(ctx);
			if (ctx.mode !== "tui") {
				ctx.ui.notify(formatSummary(loadServers(env, pi.getMcpServers()), () => pi.getAllTools()), "info");
				return;
			}
			const result = await ctx.ui.custom<PanelResult>(
				(tui, theme, keybindings, done) =>
					createMcpPanel({ tui, theme, keybindings, pi, ctx, env, done }),
				{
					overlay: true,
					overlayOptions: { anchor: "center", width: "88%", maxHeight: "80%" },
				},
			);
			if (result.message) ctx.ui.notify(result.message, "info");
			// Last use of this ctx: reload invalidates the extension runtime, which
			// is exactly how the config change above reaches builtin MCP.
			if (result.reload) await ctx.reload();
		},
	});
}
