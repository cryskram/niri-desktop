/**
 * MCP panel state — the read/write layer shared by the `/mcpx` panel and the
 * footer `mcp` status key (both live in index.ts / panel.ts).
 *
 * Reads the same two files pi's built-in MCP extension reads:
 *   - user level:    $PI_CODING_AGENT_DIR/mcp.json  (default ~/.pi/agent/mcp.json)
 *   - project level: <cwd>/.pi/mcp.json             (trusted projects only)
 * and mirrors pi's merge rules (dist/extensions/mcp/config.js): a project entry
 * without command/url/type is a partial override of the global server with the
 * same name and may only set enabled/exposure/toolExposure.
 *
 * Live connection state is derived from pi.getAllTools(): a connected server's
 * tools are registered under the namespace `mcp__<server>` (mcpNamespace()).
 * Caveat: a server filtered out by --tools/--exclude-tools looks disconnected.
 *
 * Writes mirror pi's updateMcpServerConfig(): other content is kept, the file's
 * own indentation is preserved, and default values are removed instead of
 * written. Because ~/.pi/agent/mcp.json is a home-manager store symlink (read
 * only), a failed global write falls back to a project override — the same
 * escape hatch pi offers as "Disable in this project".
 */
import {
	closeSync,
	existsSync,
	mkdirSync,
	openSync,
	readFileSync,
	readSync,
	statSync,
	writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import type { RegisteredMcpServer, ToolInfo } from "@earendil-works/pi-coding-agent";

export type ServerScope = "global" | "project" | "extension";
export type Exposure = "codemode" | "deferred" | "direct" | "hidden";

/** Exposure cycle used by the panel's `e` key. */
export const EXPOSURE_CYCLE: Exposure[] = ["codemode", "deferred", "direct", "hidden"];

export interface McpServerEntry {
	name: string;
	/** Effective config: the project override merged over the defining entry. */
	config: Record<string, unknown>;
	/** File that defines the server (extension path for session registrations). */
	sourcePath: string;
	scope: ServerScope;
	/** Project file holding a partial override of this server, when present. */
	overridePath?: string;
	extensionPath?: string;
}

export interface ConfigEnv {
	agentDir: string;
	cwd: string;
	projectTrusted: boolean;
}

export interface LoadResult {
	servers: McpServerEntry[];
	errors: string[];
	projectConfigPath: string;
}

export type EditResult =
	| { ok: true; path: string; usedOverride: boolean }
	| { ok: false; error: string };

const OVERRIDE_KEYS = ["enabled", "exposure", "toolExposure"];
const NAME_RE = /^[A-Za-z0-9_-]+$/;

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** A partial entry that overrides a server defined elsewhere instead of defining one. */
function isOverride(value: Record<string, unknown>): boolean {
	return value.command === undefined && value.url === undefined && value.type === undefined;
}

function errorMessage(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}

/** pi's mcpNamespace(): `mcp__<server>` with `-` folded to `_`. */
export function namespaceOf(server: string): string {
	return `mcp__${server.replace(/-/g, "_")}`;
}

function readConfigFile(
	path: string,
	scope: "global" | "project",
	servers: Map<string, McpServerEntry>,
	errors: string[],
): void {
	if (!existsSync(path)) return;
	let parsed: unknown;
	try {
		parsed = JSON.parse(readFileSync(path, "utf8"));
	} catch (error) {
		errors.push(`${path}: ${errorMessage(error)}`);
		return;
	}
	if (!isRecord(parsed) || (parsed.mcpServers !== undefined && !isRecord(parsed.mcpServers))) {
		errors.push(`${path}: expected an object with an "mcpServers" object`);
		return;
	}
	for (const [name, value] of Object.entries(parsed.mcpServers ?? {})) {
		if (!NAME_RE.test(name)) {
			errors.push(`${path}: server "${name}": names may only contain letters, digits, "_" and "-"`);
			continue;
		}
		if (!isRecord(value)) {
			errors.push(`${path}: server "${name}": expected an object`);
			continue;
		}
		if (scope === "project" && isOverride(value)) {
			const base = servers.get(name);
			const extra = Object.keys(value).filter((key) => !OVERRIDE_KEYS.includes(key));
			if (!base) {
				errors.push(`${path}: server "${name}" needs "command" or "url", or a global server to override`);
			} else if (extra.length > 0) {
				errors.push(`${path}: server "${name}": an override can only set ${OVERRIDE_KEYS.join(", ")}`);
			} else {
				servers.set(name, { ...base, config: { ...base.config, ...value }, overridePath: path });
			}
		} else {
			servers.set(name, { name, config: value, sourcePath: path, scope });
		}
	}
}

/** Configured servers in file order (global first), plus optional extension registrations. */
export function loadServers(
	env: ConfigEnv,
	registered: RegisteredMcpServer[] = [],
): LoadResult {
	const servers = new Map<string, McpServerEntry>();
	const errors: string[] = [];
	readConfigFile(join(env.agentDir, "mcp.json"), "global", servers, errors);
	const projectConfigPath = join(env.cwd, ".pi", "mcp.json");
	if (env.projectTrusted) readConfigFile(projectConfigPath, "project", servers, errors);
	for (const reg of registered) {
		if (servers.has(reg.name) || !NAME_RE.test(reg.name)) continue;
		servers.set(reg.name, {
			name: reg.name,
			config: reg.config as unknown as Record<string, unknown>,
			sourcePath: reg.extensionPath,
			scope: "extension",
			extensionPath: reg.extensionPath,
		});
	}
	return { servers: [...servers.values()], errors, projectConfigPath };
}

export function isEnabled(entry: McpServerEntry): boolean {
	return entry.config.enabled !== false;
}

export function exposureOf(entry: McpServerEntry): Exposure {
	const value = entry.config.exposure;
	return value === "deferred" || value === "direct" || value === "hidden" ? value : "codemode";
}

// ---------------------------------------------------------------------------- Live tool state

export interface LiveTool {
	/** pi's tool name, e.g. mcp__veridb__query — what the model actually calls. */
	name: string;
	/** Server-facing name, e.g. query. */
	shortName: string;
	description: string;
	exposure: ToolInfo["exposure"];
	annotations?: ToolInfo["annotations"];
}

/** Last tools seen per server, so a disconnected server still shows its list. */
const lastSeenTools = new Map<string, LiveTool[]>();

export function forgetLiveState(): void {
	lastSeenTools.clear();
}

export function serverTools(getAll: () => ToolInfo[], serverName: string): LiveTool[] {
	const prefix = `${namespaceOf(serverName)}__`;
	const tools: LiveTool[] = [];
	for (const tool of getAll()) {
		if (tool.namespace?.name !== namespaceOf(serverName)) continue;
		tools.push({
			name: tool.name,
			shortName: tool.name.startsWith(prefix) ? tool.name.slice(prefix.length) : tool.name,
			description: (tool.description ?? "").split("\n")[0] ?? "",
			exposure: tool.exposure,
			annotations: tool.annotations,
		});
	}
	return tools;
}

/** Live tools for every server; connected lists refresh the last-seen cache. */
export function snapshotTools(getAll: () => ToolInfo[], servers: McpServerEntry[]): Map<string, LiveTool[]> {
	const byServer = new Map<string, LiveTool[]>();
	for (const entry of servers) {
		if (entry.scope === "extension") continue;
		const live = serverTools(getAll, entry.name);
		if (live.length > 0) lastSeenTools.set(entry.name, live);
		byServer.set(entry.name, live.length > 0 ? live : (lastSeenTools.get(entry.name) ?? []));
	}
	return byServer;
}

/** `● dummy(3) · ○ veridb` — enabled servers only; disabled ones disappear (footer contract). */
export function footerStatus(servers: McpServerEntry[], getAll: () => ToolInfo[]): string | undefined {
	const parts: string[] = [];
	for (const entry of servers) {
		if (!isEnabled(entry) || entry.scope === "extension") continue;
		const live = serverTools(getAll, entry.name);
		parts.push(live.length > 0 ? `● ${entry.name}(${live.length})` : `○ ${entry.name}`);
	}
	return parts.length > 0 ? parts.join(" · ") : undefined;
}

/** Plain-text status for non-TUI modes (`/mcpx` outside the interactive TUI). */
export function formatSummary(result: LoadResult, getAll: () => ToolInfo[]): string {
	if (result.servers.length === 0 && result.errors.length === 0) {
		return "No MCP servers configured.";
	}
	const lines = result.servers.map((entry) => {
		const live = serverTools(getAll, entry.name);
		const state = !isEnabled(entry)
			? "disabled"
			: live.length > 0
				? `connected, ${live.length} tools`
				: "not connected";
		const where = entry.overridePath
			? `${entry.sourcePath} + override ${entry.overridePath}`
			: entry.sourcePath;
		return `${entry.name}: ${state}, exposure ${exposureOf(entry)}, ${entry.scope} (${where})`;
	});
	for (const error of result.errors) lines.push(`config: ${error}`);
	return lines.join("\n");
}

// ---------------------------------------------------------------------------- Config writes

function editServerConfig(path: string, name: string, patch: { enabled?: boolean; exposure?: Exposure }, asOverride: boolean): void {
	const text = existsSync(path) ? readFileSync(path, "utf8") : undefined;
	const parsed: unknown = text === undefined ? {} : JSON.parse(text);
	if (!isRecord(parsed) || (parsed.mcpServers !== undefined && !isRecord(parsed.mcpServers))) {
		throw new Error(`${path}: expected an object with an "mcpServers" object`);
	}
	const servers = isRecord(parsed.mcpServers) ? parsed.mcpServers : undefined;
	let server: unknown = servers?.[name];
	if (server === undefined && asOverride) {
		server = {};
		parsed.mcpServers = { ...(servers ?? {}), [name]: server };
	}
	if (!isRecord(server)) throw new Error(`${path} does not define MCP server "${name}"`);
	// Overrides replace the global server's defaults, so defaults stay explicit there.
	const keepDefaults = isOverride(server);
	if (patch.enabled !== undefined) {
		if (patch.enabled && !keepDefaults) delete server.enabled;
		else server.enabled = patch.enabled;
	}
	if (patch.exposure !== undefined) {
		if (patch.exposure === "codemode" && !keepDefaults) delete server.exposure;
		else server.exposure = patch.exposure;
	}
	const indent = (text && /^([ \t]+)\S/m.exec(text)?.[1]) || "  ";
	mkdirSync(dirname(path), { recursive: true });
	writeFileSync(path, `${JSON.stringify(parsed, null, indent)}\n`);
}

/**
 * Apply an enabled/exposure patch to the file that defines the server
 * (its project override when one exists). A read-only defining file — the
 * home-manager store symlink at ~/.pi/agent/mcp.json — falls back to writing a
 * project override instead, so the change survives in this project.
 */
export function editServer(
	entry: McpServerEntry,
	patch: { enabled?: boolean; exposure?: Exposure },
	env: ConfigEnv,
): EditResult {
	if (entry.scope === "extension") {
		return { ok: false, error: `${entry.name} is registered by an extension and is session-only.` };
	}
	const primary = entry.overridePath ?? entry.sourcePath;
	try {
		editServerConfig(primary, entry.name, patch, false);
		return { ok: true, path: primary, usedOverride: entry.overridePath !== undefined };
	} catch (error) {
		const primaryError = errorMessage(error);
		const canFallback = entry.scope === "global" && entry.overridePath === undefined && env.projectTrusted;
		if (!canFallback) return { ok: false, error: primaryError };
		const fallback = join(env.cwd, ".pi", "mcp.json");
		try {
			editServerConfig(fallback, entry.name, patch, true);
			return { ok: true, path: fallback, usedOverride: true };
		} catch (fallbackError) {
			return {
				ok: false,
				error: `${primaryError} — project override also failed: ${errorMessage(fallbackError)}`,
			};
		}
	}
}

// ---------------------------------------------------------------------------- Diagnostics

/** Tail of ~/.pi/agent/mcp.log for one server (server log lines look like `… [name] …`). */
export function logTail(agentDir: string, serverName: string, max = 6): string[] {
	const path = join(agentDir, "mcp.log");
	try {
		const size = statSync(path).size;
		const start = Math.max(0, size - 65536);
		const length = size - start;
		if (length <= 0) return [];
		const fd = openSync(path, "r");
		try {
			const buffer = Buffer.alloc(length);
			readSync(fd, buffer, 0, length, start);
			const lines = buffer.toString("utf8").split("\n").filter((line) => line.includes(`[${serverName}]`));
			return lines.filter((line) => line.trim().length > 0).slice(-max);
		} finally {
			closeSync(fd);
		}
	} catch {
		return [];
	}
}

/** First line of a config description, for the details pane. */
export function describeServer(entry: McpServerEntry): string | undefined {
	const description = entry.config.description;
	if (typeof description !== "string") return undefined;
	const first = description.split("\n")[0]?.trim();
	return first ? first : undefined;
}
