/**
 * Editor stash — `Alt+S` parks the draft you were typing and hands back a clean
 * editor; `Alt+S` again gives it back.
 *
 * This is the one feature of pi-powerline-footer worth keeping without the
 * footer. Same four-state toggle as its README described:
 *
 *   | Editor   | Stash | Alt+S                               |
 *   |----------|-------|-------------------------------------|
 *   | has text | empty | stash the text, clear the editor    |
 *   | empty    | set   | restore it, and pop the stash       |
 *   | has text | set   | replace the stash with the new text |
 *   | empty    | empty | "Nothing to stash"                  |
 *
 * A stash is never restored behind your back: agent runs do not touch it, only
 * an explicit toggle or history pick does. Stashing while the agent is busy is
 * the main use case — park the long prompt, ask a quick question instead.
 *
 * Storage has two tiers, both pi-native:
 *   - Active stash: a `custom` session entry (`pi.appendEntry`), which is kept
 *     out of model context. It therefore survives `/reload` and resume, and
 *     follows the branch it was created on rather than leaking into a new one.
 *   - Recent drafts: `$PI_CODING_AGENT_DIR/stash-history.json`, newest first,
 *     bounded, written atomically at mode 0600 (a draft can hold anything).
 *
 * Commands: `/stash` (toggle, same as the shortcut), `/stash-history` (pick a
 * past draft, Replace or Append when the editor already has text),
 * `/stash-clear`.
 *
 * Declarative: loaded via modules/core.nix `programs.pi.coding-agent.extensions`.
 * The shortcut fires only while the default editor has focus, so it cannot
 * shadow `/tree`, selector, or model-picker keys.
 */

import { chmodSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STASH_ENTRY = "stash";
const STATUS_KEY = "stash";
const HISTORY_LIMIT = 25;
const PICKER_LIMIT = 12;

type Draft = {
	text: string;
	at: string;
};

/** The active stash of the current session branch. */
let active: Draft | undefined;

function agentDir(): string {
	return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
}

function historyPath(): string {
	return join(agentDir(), "stash-history.json");
}

function readHistory(): Draft[] {
	try {
		const parsed: unknown = JSON.parse(readFileSync(historyPath(), "utf8"));
		if (!Array.isArray(parsed)) return [];
		return parsed.filter(
			(entry): entry is Draft =>
				typeof entry === "object" && entry !== null && typeof (entry as Draft).text === "string" && (entry as Draft).text.trim() !== "",
		);
	} catch {
		return [];
	}
}

/** Newest first, no duplicates, bounded. Atomic so a draft is never half-written. */
function pushHistory(draft: Draft): void {
	const next = [draft, ...readHistory().filter((entry) => entry.text !== draft.text)].slice(0, HISTORY_LIMIT);
	try {
		mkdirSync(agentDir(), { recursive: true, mode: 0o700 });
		const tmp = `${historyPath()}.tmp`;
		writeFileSync(tmp, `${JSON.stringify(next, null, 2)}\n`, { mode: 0o600 });
		renameSync(tmp, historyPath());
		chmodSync(historyPath(), 0o600);
	} catch {
		// History is a convenience; never block a stash on it.
	}
}

function lineCount(text: string): number {
	return text.split("\n").length;
}

function describe(text: string): string {
	const lines = lineCount(text);
	return `${lines} line${lines === 1 ? "" : "s"}`;
}

function firstLine(text: string): string {
	const line = text.trim().split("\n")[0] ?? "";
	return line.length > 60 ? `${line.slice(0, 57)}…` : line;
}

function ago(iso: string): string {
	const elapsed = Date.now() - Date.parse(iso);
	if (!Number.isFinite(elapsed) || elapsed < 60_000) return "just now";
	const minutes = Math.floor(elapsed / 60_000);
	if (minutes < 60) return `${minutes}m ago`;
	const hours = Math.floor(minutes / 60);
	if (hours < 24) return `${hours}h ago`;
	const days = Math.floor(hours / 24);
	return days === 1 ? "yesterday" : `${days}d ago`;
}

/** Footer indicator: `stash 12l`, gone when nothing is stashed. */
function publish(ctx: ExtensionContext): void {
	if (!ctx.hasUI) return;
	try {
		ctx.ui.setStatus(STATUS_KEY, active ? `stash ${lineCount(active.text)}l` : undefined);
	} catch {
		// Footer bookkeeping must never break the toggle.
	}
}

/** Mirror the stash into the session branch so /reload and resume keep it. */
function persist(pi: ExtensionAPI, draft: Draft | undefined): void {
	active = draft;
	try {
		pi.appendEntry(STASH_ENTRY, draft);
	} catch {
		// A session that refuses entries still gets in-memory stashing.
	}
}

/** Last stash entry on the active branch, so branches cannot leak into each other. */
function fromBranch(ctx: ExtensionContext): Draft | undefined {
	const entries = ctx.sessionManager.getBranch();
	for (let index = entries.length - 1; index >= 0; index -= 1) {
		const entry = entries[index] as { type?: string; customType?: string; data?: UnknownDraft };
		if (entry?.type !== "custom" || entry.customType !== STASH_ENTRY) continue;
		const data = entry.data;
		return typeof data?.text === "string" && data.text.trim() !== "" ? { text: data.text, at: typeof data.at === "string" ? data.at : new Date().toISOString() } : undefined;
	}
	return undefined;
}

type UnknownDraft = { text?: unknown; at?: unknown };

function toggle(pi: ExtensionAPI, ctx: ExtensionContext): void {
	if (!ctx.hasUI) return;
	const editorText = ctx.ui.getEditorText();
	const draftText = editorText.trim() === "" ? "" : editorText;

	if (draftText !== "") {
		const replacing = active !== undefined;
		const draft: Draft = { text: draftText, at: new Date().toISOString() };
		persist(pi, draft);
		ctx.ui.setEditorText("");
		pushHistory(draft);
		publish(ctx);
		ctx.ui.notify(replacing ? `Stash updated · ${describe(draftText)}` : `Stashed ${describe(draftText)} · Alt+S to restore`, "info");
		return;
	}

	if (active) {
		const restored = active.text;
		persist(pi, undefined);
		ctx.ui.setEditorText(restored);
		publish(ctx);
		ctx.ui.notify(`Restored ${describe(restored)}`, "info");
		return;
	}

	ctx.ui.notify("Nothing to stash", "info");
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		active = fromBranch(ctx);
		publish(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		active = undefined;
		try {
			ctx.ui.setStatus(STATUS_KEY, undefined);
		} catch {
			// Shutdown cleanup stays quiet.
		}
	});

	pi.registerShortcut("alt+s", {
		description: "Stash or restore the editor draft",
		handler: (ctx) => toggle(pi, ctx),
	});

	pi.registerCommand("stash", {
		description: "Stash or restore the editor draft (same as Alt+S)",
		handler: async (_args, ctx) => toggle(pi, ctx),
	});

	pi.registerCommand("stash-clear", {
		description: "Discard the active stash",
		handler: async (_args, ctx) => {
			if (!active) {
				ctx.ui.notify("Nothing stashed", "info");
				return;
			}
			const discarded = describe(active.text);
			persist(pi, undefined);
			publish(ctx);
			ctx.ui.notify(`Discarded ${discarded}`, "info");
		},
	});

	pi.registerCommand("stash-history", {
		description: "Insert a previously stashed draft",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			const history = readHistory().slice(0, PICKER_LIMIT);
			if (history.length === 0) {
				ctx.ui.notify("No stash history yet", "info");
				return;
			}
			const labels = history.map((draft) => `${ago(draft.at)} · ${firstLine(draft.text)}`);
			const picked = await ctx.ui.select("Stash history", labels);
			if (picked === undefined) return;
			const draft = history[labels.indexOf(picked)];
			if (!draft) return;

			const current = ctx.ui.getEditorText();
			if (current.trim() === "") {
				ctx.ui.setEditorText(draft.text);
				ctx.ui.notify(`Inserted ${describe(draft.text)} from history`, "info");
				return;
			}

			const mode = await ctx.ui.select(`Editor has text — ${describe(current)}`, ["Replace", "Append", "Cancel"]);
			if (mode === "Replace") {
				ctx.ui.setEditorText(draft.text);
				ctx.ui.notify(`Replaced editor with ${describe(draft.text)} from history`, "info");
			} else if (mode === "Append") {
				ctx.ui.setEditorText(`${current.replace(/\s+$/, "")}\n${draft.text}`);
				ctx.ui.notify(`Appended ${describe(draft.text)} from history`, "info");
			}
		},
	});
}
