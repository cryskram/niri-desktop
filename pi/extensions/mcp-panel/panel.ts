/**
 * `/mcpx` panel — a native-backed recreation of the pi-mcp-adapter panel.
 *
 * It intentionally does NOT register `/mcp`: pi's built-in MCP extension is
 * `replaceable`, so taking that command would unload builtin MCP entirely
 * (dist/core/resource-loader.js omitReplacedExtensions) and nothing would read
 * mcp.json or connect servers. Instead this panel observes native state:
 * config files (state.ts) plus pi.getAllTools() namespaces for live connection
 * state, and applies toggles by writing the config and asking the command
 * handler to /reload — pi re-emits session_start on reload, so builtin MCP
 * re-reads the config and the change lands immediately.
 *
 * Keys: ↑↓/jk move · / filter · enter tools · d toggle · e exposure ·
 *       r reload-reconnect · c paste `/mcp reconnect` · i log · esc/q close
 */
import type { ExtensionAPI, ExtensionCommandContext, Theme } from "@earendil-works/pi-coding-agent";
import type { Component, Focusable, KeybindingsManager, TUI } from "@earendil-works/pi-tui";
import { fuzzyFilter, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import {
	EXPOSURE_CYCLE,
	describeServer,
	editServer,
	exposureOf,
	isEnabled,
	loadServers,
	logTail,
	snapshotTools,
	type ConfigEnv,
	type LiveTool,
	type McpServerEntry,
} from "./state.ts";

export interface PanelResult {
	/** Ask the /mcpx command handler to run ctx.reload() after the panel closes. */
	reload?: boolean;
	message?: string;
}

export interface PanelDeps {
	tui: TUI;
	theme: Theme;
	keybindings: KeybindingsManager;
	pi: ExtensionAPI;
	ctx: ExtensionCommandContext;
	env: ConfigEnv;
	done: (result: PanelResult) => void;
}

type Mode = "servers" | "tools";
type EditMode = "none" | "serverFilter" | "toolFilter";

interface Notice {
	text: string;
	kind: "info" | "error";
}

const REFRESH_MS = 500;

function isPrintable(data: string): boolean {
	return data.length > 0 && !/[\x00-\x1f\x7f]/.test(data);
}

function firstLine(text: string | undefined): string | undefined {
	if (!text) return undefined;
	const line = text.split("\n")[0]?.trim();
	return line ? line : undefined;
}

/** Keep the selected item inside a window of `size` rows. */
function windowStart(names: string[], selected: string | undefined, size: number): number {
	if (names.length <= size) return 0;
	const index = Math.max(0, names.findIndex((name) => name === selected));
	return Math.max(0, Math.min(names.length - size, index - Math.floor(size / 2)));
}

class McpPanel implements Component, Focusable {
	focused = true;
	private deps: PanelDeps;
	private mode: Mode = "servers";
	private editMode: EditMode = "none";
	private filter = "";
	private toolFilter = "";
	private selectedName: string | undefined;
	private selectedTool: string | undefined;
	private showLog = false;
	private notice: Notice | undefined;
	private servers: McpServerEntry[] = [];
	private toolsByServer = new Map<string, LiveTool[]>();
	private configErrors: string[] = [];
	private lastRefresh = 0;

	constructor(deps: PanelDeps) {
		this.deps = deps;
		this.refresh();
	}

	// ------------------------------------------------------------------ state

	private refresh(): void {
		this.lastRefresh = Date.now();
		const result = loadServers(this.deps.env, this.deps.pi.getMcpServers());
		this.servers = result.servers;
		this.configErrors = result.errors;
		this.toolsByServer = snapshotTools(() => this.deps.pi.getAllTools(), this.servers);
	}

	private refreshIfStale(): void {
		if (Date.now() - this.lastRefresh >= REFRESH_MS) this.refresh();
	}

	private visibleServers(): McpServerEntry[] {
		if (!this.filter) return this.servers;
		return fuzzyFilter(this.servers, this.filter, (entry) => entry.name);
	}

	private selected(): McpServerEntry | undefined {
		const list = this.visibleServers();
		return list.find((entry) => entry.name === this.selectedName) ?? list[0];
	}

	private toolsOf(entry: McpServerEntry | undefined): LiveTool[] {
		return entry ? (this.toolsByServer.get(entry.name) ?? []) : [];
	}

	private visibleTools(entry: McpServerEntry | undefined): LiveTool[] {
		const tools = this.toolsOf(entry);
		if (!this.toolFilter) return tools;
		return fuzzyFilter(tools, this.toolFilter, (tool) => `${tool.shortName} ${tool.description}`);
	}

	private selectedToolOf(entry: McpServerEntry | undefined): LiveTool | undefined {
		const list = this.visibleTools(entry);
		return list.find((tool) => tool.name === this.selectedTool) ?? list[0];
	}

	// ------------------------------------------------------------------ input

	handleInput(data: string): void {
		this.notice = undefined;
		const kb = this.deps.keybindings;

		// Filter editing submode: printable characters build the query.
		if (this.editMode !== "none") {
			const serverFilter = this.editMode === "serverFilter";
			if (matchesKey(data, "escape")) {
				if (serverFilter) this.filter = "";
				else this.toolFilter = "";
				this.editMode = "none";
			} else if (kb.matches(data, "tui.select.confirm")) {
				this.editMode = "none";
			} else if (matchesKey(data, "backspace")) {
				if (serverFilter) this.filter = this.filter.slice(0, -1);
				else this.toolFilter = this.toolFilter.slice(0, -1);
			} else if (kb.matches(data, "tui.select.up")) {
				this.move(-1);
			} else if (kb.matches(data, "tui.select.down")) {
				this.move(1);
			} else if (isPrintable(data)) {
				if (serverFilter) this.filter += data;
				else this.toolFilter += data;
			}
			this.deps.tui.requestRender();
			return;
		}

		if (kb.matches(data, "tui.select.up") || matchesKey(data, "k")) {
			this.move(-1);
		} else if (kb.matches(data, "tui.select.down") || matchesKey(data, "j")) {
			this.move(1);
		} else if (matchesKey(data, "/")) {
			this.editMode = this.mode === "tools" ? "toolFilter" : "serverFilter";
		} else if (kb.matches(data, "tui.select.confirm") || matchesKey(data, "enter")) {
			this.toggleView();
		} else if (matchesKey(data, "d")) {
			this.toggleEnabled();
		} else if (matchesKey(data, "e")) {
			this.cycleExposure();
		} else if (matchesKey(data, "r")) {
			this.deps.done({ reload: true, message: "Reloading to reconnect MCP servers…" });
		} else if (matchesKey(data, "c")) {
			this.pasteReconnect();
		} else if (matchesKey(data, "i")) {
			this.showLog = !this.showLog;
		} else if (matchesKey(data, "escape")) {
			this.escape();
		} else if (matchesKey(data, "q")) {
			this.deps.done({});
		}
		this.deps.tui.requestRender();
	}

	private move(delta: number): void {
		if (this.mode === "servers") {
			const list = this.visibleServers();
			if (list.length === 0) return;
			const current = this.selected()?.name;
			const index = Math.max(0, list.findIndex((entry) => entry.name === current));
			const next = Math.min(list.length - 1, Math.max(0, index + delta));
			this.selectedName = list[next]?.name;
		} else {
			const entry = this.selected();
			const list = this.visibleTools(entry);
			if (list.length === 0) return;
			const current = this.selectedToolOf(entry)?.name;
			const index = Math.max(0, list.findIndex((tool) => tool.name === current));
			const next = Math.min(list.length - 1, Math.max(0, index + delta));
			this.selectedTool = list[next]?.name;
		}
	}

	private toggleView(): void {
		if (this.mode === "servers") {
			const entry = this.selected();
			if (!entry) return;
			if (this.toolsOf(entry).length === 0) {
				this.notice = { text: `No tools seen for ${entry.name} yet (connect it first).`, kind: "info" };
				return;
			}
			this.mode = "tools";
			this.selectedTool = undefined;
			this.toolFilter = "";
		} else {
			this.mode = "servers";
			this.toolFilter = "";
		}
	}

	private escape(): void {
		if (this.filter) {
			this.filter = "";
		} else if (this.mode === "tools") {
			this.mode = "servers";
			this.toolFilter = "";
		} else {
			this.deps.done({});
		}
	}

	private toggleEnabled(): void {
		const entry = this.selected();
		if (!entry) return;
		const enabling = !isEnabled(entry);
		const result = editServer(entry, { enabled: enabling }, this.deps.env);
		if (!result.ok) {
			this.notice = { text: result.error, kind: "error" };
			return;
		}
		const via = result.usedOverride ? " (project override)" : "";
		this.deps.done({
			reload: true,
			message: `${enabling ? "Enabled" : "Disabled"} ${entry.name}${via} — reloading…`,
		});
	}

	private cycleExposure(): void {
		const entry = this.selected();
		if (!entry) return;
		const current = exposureOf(entry);
		const next = EXPOSURE_CYCLE[(EXPOSURE_CYCLE.indexOf(current) + 1) % EXPOSURE_CYCLE.length] ?? "codemode";
		const result = editServer(entry, { exposure: next }, this.deps.env);
		if (!result.ok) {
			this.notice = { text: result.error, kind: "error" };
			return;
		}
		const via = result.usedOverride ? " (project override)" : "";
		this.deps.done({
			reload: true,
			message: `${entry.name}: exposure ${current} → ${next}${via} — reloading…`,
		});
	}

	private pasteReconnect(): void {
		const entry = this.selected();
		if (!entry) return;
		// Extensions cannot invoke other commands, so hand the native flow to the editor.
		this.deps.ctx.ui.pasteToEditor(`/mcp reconnect ${entry.name}`);
		this.deps.done({});
	}

	// ------------------------------------------------------------------ render

	invalidate(): void {
		// Nothing is cached: every render recomputes from config + live tools.
	}

	render(width: number): string[] {
		this.refreshIfStale();
		const th = this.deps.theme;
		if (width < 30) return [th.fg("muted", "MCP panel: terminal too narrow.")];

		const inner = width - 4;
		const rows = this.deps.tui.terminal?.rows ?? 24;
		const contentRows = Math.max(8, Math.min(30, Math.floor(rows * 0.8)) - 2);

		const servers = this.visibleServers();
		const entry = this.selected();
		if (entry && this.selectedName !== entry.name) this.selectedName = entry.name;

		const details = this.buildDetails(entry, inner);
		const noticeLines = this.notice ? [this.notice.text] : [];
		const keys = this.buildKeys(inner);
		const used = 1 /* summary */ + 1 /* separator */ + details.length + noticeLines.length + keys.length;
		const listRows = Math.max(3, contentRows - used);

		const lines: string[] = [];
		lines.push(this.topBorder(width));
		lines.push(this.boxLine(this.buildSummary(servers, entry), inner));

		if (this.mode === "servers") {
			const activeIndex = entry ? servers.indexOf(entry) : -1;
			const start = windowStart(servers.map((server) => server.name), this.selectedName, listRows);
			const end = Math.min(servers.length, start + listRows);
			for (let index = start; index < end; index++) {
				lines.push(this.boxLine(this.serverRow(servers[index]!, inner, index === activeIndex), inner));
			}
			for (let index = end - start; index < listRows; index++) {
				lines.push(this.boxLine("", inner));
			}
		} else {
			const tools = this.visibleTools(entry);
			const activeTool = this.selectedToolOf(entry);
			if (activeTool && this.selectedTool !== activeTool.name) this.selectedTool = activeTool.name;
			const start = windowStart(tools.map((tool) => tool.name), this.selectedTool, listRows);
			const end = Math.min(tools.length, start + listRows);
			for (let index = start; index < end; index++) {
				lines.push(this.boxLine(this.toolRow(tools[index]!, inner, tools[index] === activeTool), inner));
			}
			for (let index = end - start; index < listRows; index++) {
				lines.push(this.boxLine("", inner));
			}
		}

		lines.push(th.fg("border", "├") + "─".repeat(inner) + th.fg("border", "┤"));
		for (const line of details) lines.push(this.boxLine(line, inner));
		for (const line of noticeLines) {
			lines.push(this.boxLine(this.fit(th.fg(this.notice?.kind === "error" ? "error" : "warning", line), inner), inner));
		}
		for (const line of keys) lines.push(this.boxLine(line, inner));
		lines.push(th.fg("border", "└") + "─".repeat(inner) + th.fg("border", "┘"));
		return lines;
	}

	private topBorder(width: number): string {
		const th = this.deps.theme;
		const title = this.mode === "tools" ? " MCP tools " : " MCP servers ";
		const fill = Math.max(1, width - 2 - visibleWidth(title));
		return th.fg("border", "┌") + th.fg("accent", title) + th.fg("border", "─".repeat(fill) + "┐");
	}

	private boxLine(content: string, inner: number): string {
		const th = this.deps.theme;
		return th.fg("border", "│ ") + this.pad(content, inner) + th.fg("border", " │");
	}

	private fit(text: string, width: number): string {
		return truncateToWidth(text, Math.max(0, width), "");
	}

	private pad(text: string, width: number): string {
		const fitted = this.fit(text, width);
		return fitted + " ".repeat(Math.max(0, width - visibleWidth(fitted)));
	}

	private buildSummary(servers: McpServerEntry[], entry: McpServerEntry | undefined): string {
		const th = this.deps.theme;
		const enabled = servers.filter(isEnabled).length;
		const connected = servers.filter((server) => isEnabled(server) && this.toolsOf(server).length > 0).length;
		let text = `${th.fg("accent", String(servers.length))} servers · ${connected}/${enabled} connected`;
		if (this.filter) text += `   ${th.fg("accent", `/${this.filter}`)}`;
		if (this.mode === "tools" && entry && this.toolFilter) {
			text += `   ${th.fg("accent", `filter: ${this.toolFilter}`)}`;
		}
		if (this.configErrors.length > 0) {
			text += `   ${th.fg("warning", `! ${this.configErrors.length} config warning(s)`)}`;
		}
		return text;
	}

	private serverRow(entry: McpServerEntry, width: number, selected: boolean): string {
		const th = this.deps.theme;
		const enabled = isEnabled(entry);
		const live = this.toolsOf(entry);
		const connected = enabled && live.length > 0;
		const glyph = connected ? "●" : "○";
		const glyphColor = !enabled ? "dim" : connected ? "success" : "warning";
		const status = !enabled ? "disabled" : connected ? `${live.length} tools` : "not connected";
		const scope = entry.overridePath ? "override" : entry.scope;
		const colored =
			(selected ? th.fg("accent", "› ") : "  ") +
			th.fg(glyphColor, glyph) +
			` ${entry.name}`.padEnd(17) +
			exposureOf(entry).padEnd(9) +
			`${scope}`.padEnd(9) +
			(!enabled ? th.fg("dim", status) : status);
		const body = this.pad(colored, width);
		return selected ? th.style(body, { bg: "selectedBg" }) : body;
	}

	private toolRow(tool: LiveTool, width: number, selected: boolean): string {
		const th = this.deps.theme;
		const marks: string[] = [];
		if (tool.exposure !== "codemode") marks.push(tool.exposure);
		if (tool.annotations?.readOnlyHint) marks.push("read-only");
		const colored =
			(selected ? th.fg("accent", "› ") : "  ") +
			th.fg("success", "●") +
			` ${tool.shortName}`.padEnd(29) +
			(marks.length > 0 ? th.fg("warning", `[${marks.join(", ")}] `) : "") +
			(tool.description ? this.fit(tool.description, Math.max(10, width - 34)) : "");
		const body = this.pad(colored, width);
		return selected ? th.style(body, { bg: "selectedBg" }) : body;
	}

	private buildDetails(entry: McpServerEntry | undefined, inner: number): string[] {
		const th = this.deps.theme;
		if (!entry) return [th.fg("muted", "No MCP servers configured. Add servers to mcp.json or .pi/mcp.json.")];
		const lines: string[] = [];

		if (this.mode === "tools") {
			const tool = this.selectedToolOf(entry);
			if (tool) {
				lines.push(`${th.fg("accent", tool.shortName)}  ${th.fg("muted", tool.name)}`);
				const flags: string[] = [tool.exposure];
				if (tool.annotations?.readOnlyHint) flags.push("read-only");
				lines.push(th.fg("muted", flags.join(" · ")));
				const description = firstLine(tool.description);
				if (description) lines.push(this.fit(description, inner));
			}
			return lines;
		}

		const description = describeServer(entry);
		const suffix = description ? `  ${this.fit(description, Math.max(10, inner - entry.name.length - 2))}` : "";
		lines.push(`${th.fg("accent", entry.name)}${suffix}`);

		const enabled = isEnabled(entry);
		const live = this.toolsOf(entry);
		const state = !enabled
			? th.fg("dim", "disabled")
			: live.length > 0
				? th.fg("success", `connected · ${live.length} tools`)
				: th.fg("warning", "not connected");
		lines.push(`${th.fg("muted", "state   ")}${state} · exposure ${exposureOf(entry)}`);

		const source = entry.overridePath ? `${entry.sourcePath} + ${entry.overridePath}` : entry.sourcePath;
		lines.push(`${th.fg("muted", "source  ")}${this.fit(source, Math.max(10, inner - 8))}`);

		if (this.showLog) {
			const tail = logTail(this.deps.env.agentDir, entry.name, 4);
			if (tail.length === 0) {
				lines.push(`${th.fg("muted", "log     ")}no recent entries for [${entry.name}]`);
			} else {
				for (const line of tail) {
					lines.push(`${th.fg("muted", "log     ")}${this.fit(line, Math.max(10, inner - 8))}`);
				}
			}
		} else {
			const names = live.slice(0, 3).map((tool) => tool.shortName).join(", ");
			const rest = live.length - Math.min(3, live.length);
			const summary = live.length > 0 ? `${names}${rest > 0 ? ` … (+${rest})` : ""}` : "none yet";
			lines.push(`${th.fg("muted", "tools   ")}${this.fit(summary, Math.max(10, inner - 8))}  ${th.fg("accent", "[enter]")}`);
		}
		return lines;
	}

	private buildKeys(inner: number): string[] {
		const th = this.deps.theme;
		const key = (label: string) => th.fg("accent", label);
		const dim = (label: string) => th.fg("dim", label);
		const line1 =
			key("↑↓/jk") + dim(" move   ") +
			key("/") + dim(" filter   ") +
			key("enter") + dim(" tools   ") +
			key("d") + dim(" toggle   ") +
			key("e") + dim(" exposure");
		const line2 =
			this.mode === "servers"
				? key("r") + dim(" reconnect   ") + key("c") + dim(" native /mcp   ") + key("i") + dim(" log   ") + key("esc/q") + dim(" close")
				: key("enter/esc") + dim(" back   ") + key("d/e/r") + dim(" act on the server");
		return [this.fit(line1, inner), this.fit(line2, inner)];
	}
}

export function createMcpPanel(deps: PanelDeps): Component & { dispose?(): void } {
	return new McpPanel(deps);
}
