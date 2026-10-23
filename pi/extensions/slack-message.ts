/**
 * Slack message edit/delete — the two Web API methods the Slack MCP server does
 * not wrap.
 *
 * The MCP server on the user level (`korotovsky/slack-mcp-server`, see
 * `modules/core.nix` + `docs/slack.md`) exposes history, search, posting,
 * reactions, unreads and usergroups — but no `chat.update` and no `chat.delete`,
 * and v1.3.0 is the latest release, so there is no pin to bump.
 *
 * What is left is Small and self-contained on purpose: no HTTP client
 * dependency, no second credential store, no channel-name resolution. It reads
 * the SAME credential files as the MCP server wrapper:
 *
 *   secrets/slack-xoxc-token + secrets/slack-xoxd-token   (browser session)
 *   secrets/slack-mcp-token                               (xoxp / xoxb app)
 *
 * Channel names are deliberately NOT resolved here: `#channel` and
 * `@username_dm` resolution lives in the MCP server's caches, not in the Web API
 * path this file takes. Channel IDs and `ts` values come straight out of
 * `conversations_history` / `conversations_search_messages` output, and a message
 * permalink is accepted as a shortcut for both.
 *
 * Slack rule that no credential can bend: you can only edit or delete your OWN
 * messages (admins aside). Anything else comes back as `cant_update_message` /
 * `cant_delete_message`.
 *
 * Loading (declarative): listed in `programs.pi.coding-agent.extensions` in
 * `modules/core.nix`; gated by the `slack_*_message` rules in `settings.guard`
 * there. For a one-off run: `pi -e ./slack-message.ts`.
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const NAMESPACE = {
	name: "slack-message",
	aliases: ["slack-edit", "slack"],
	description: "Edit or delete a Slack message you posted, using the credentials the Slack MCP server already uses.",
	instructions:
		"Targets are Slack IDs, not names: take `channel` (C…/D…/G…) and `ts` from conversations_history or " +
		"conversations_search_messages output, or pass a message permalink (…/archives/C123/p1234567890123456) " +
		"as either argument. Only your own messages can be edited or deleted. Deleting asks for confirmation in " +
		"interactive sessions and is blocked in headless ones (pi-guard `slack_delete_message = \"ask\"`).",
};

const READ_WRITE = { readOnlyHint: false, destructiveHint: false, openWorldHint: true } as const;
const DESTRUCTIVE = { readOnlyHint: false, destructiveHint: true, openWorldHint: true } as const;

/** xoxc/xoxd calls are fingerprinted; a browser UA is what the tokens were minted against. */
const DEFAULT_USER_AGENT =
	"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";

interface SlackAuth {
	kind: "session" | "user" | "bot";
	source: string;
	headers: Record<string, string>;
}

function apiBase(): string {
	return (process.env.SLACK_API_BASE_URL ?? "https://slack.com/api").replace(/\/+$/, "");
}

function secretsDir(): string {
	return process.env.SLACK_MCP_SECRETS_DIR ?? join(homedir(), "niri-desktop", "secrets");
}

/** Token files are single-line and hand-written; trim anything a paste dragged in. */
function readSecretFile(path: string): string | undefined {
	try {
		const value = readFileSync(path, "utf8").replace(/[\r\n\t ]+/g, "");
		return value.length > 0 ? value : undefined;
	} catch {
		return undefined;
	}
}

/**
 * Credential resolution mirrors the MCP wrapper in `modules/core.nix`: browser
 * session first (no Slack app involved), then a single app token by prefix.
 * Environment wins over files so a one-off run can override without touching
 * `secrets/`.
 */
export function resolveAuth(): SlackAuth {
	const base = {
		"content-type": "application/json; charset=utf-8",
		"user-agent": process.env.SLACK_MCP_USER_AGENT ?? DEFAULT_USER_AGENT,
	};

	const envC = process.env.SLACK_MCP_XOXC_TOKEN;
	const envD = process.env.SLACK_MCP_XOXD_TOKEN;
	if (envC && envD) {
		return {
			kind: "session",
			source: "env SLACK_MCP_XOXC_TOKEN/SLACK_MCP_XOXD_TOKEN",
			headers: { ...base, authorization: `Bearer ${envC}`, cookie: `d=${envD}` },
		};
	}

	const dir = secretsDir();
	const fileC = readSecretFile(join(dir, "slack-xoxc-token"));
	const fileD = readSecretFile(join(dir, "slack-xoxd-token"));
	if (fileC && fileD) {
		return {
			kind: "session",
			source: join(dir, "slack-{xoxc,xoxd}-token"),
			headers: { ...base, authorization: `Bearer ${fileC}`, cookie: `d=${fileD}` },
		};
	}

	const appToken =
		process.env.SLACK_MCP_XOXP_TOKEN ??
		process.env.SLACK_MCP_XOXB_TOKEN ??
		readSecretFile(join(dir, "slack-mcp-token"));
	if (appToken) {
		return {
			kind: appToken.startsWith("xoxb-") ? "bot" : "user",
			source: process.env.SLACK_MCP_XOXP_TOKEN || process.env.SLACK_MCP_XOXB_TOKEN ? "env app token" : join(dir, "slack-mcp-token"),
			headers: { ...base, authorization: `Bearer ${appToken}` },
		};
	}

	throw new Error(
		`No Slack credentials found. Expected ${join(dir, "slack-xoxc-token")} + ${join(dir, "slack-xoxd-token")}, ` +
			`or ${join(dir, "slack-mcp-token")}. See docs/slack.md § Setup.`,
	);
}

/** Slack answers HTTP 200 with `ok:false`; the `error` string is the real failure. */
function explain(error: string, auth: SlackAuth): string {
	switch (error) {
		case "cant_update_message":
			return "Slack refused the edit: that message is not editable by you (someone else's message, or a message type Slack does not allow editing).";
		case "cant_delete_message":
			return "Slack refused the delete: that message is not deletable by you (someone else's message, or it needs admin rights).";
		case "message_not_found":
			return "No message with that channel + ts — the ts may belong to another channel, or the message was already deleted.";
		case "invalid_auth":
		case "not_authed":
		case "token_revoked":
		case "account_inactive":
			return `Authentication failed (${error}) using ${auth.source}. Session tokens rotate when you log out or change your password — recopy them (docs/slack.md § Setup).`;
		case "ratelimited":
		case "rate_limited":
			return "Slack rate-limited this call; wait a moment and retry.";
		case "missing_scope":
			return "The credential lacks the scope for this method. A browser session always has it; an app token needs `chat:write`.";
		default:
			return `Slack returned error "${error}".`;
	}
}

async function slackCall(method: string, body: Record<string, unknown>, signal?: AbortSignal): Promise<Record<string, unknown>> {
	const auth = resolveAuth();
	let response: Response;
	try {
		response = await fetch(`${apiBase()}/${method}`, {
			method: "POST",
			headers: auth.headers,
			body: JSON.stringify(body),
			signal,
		});
	} catch (error) {
		if (signal?.aborted) throw error;
		throw new Error(`Could not reach Slack (${method}): ${error instanceof Error ? error.message : String(error)}`);
	}

	const raw = await response.text();
	let payload: Record<string, unknown>;
	try {
		payload = JSON.parse(raw) as Record<string, unknown>;
	} catch {
		throw new Error(`Slack ${method} returned ${response.status} with a non-JSON body: ${raw.slice(0, 200)}`);
	}
	if (payload.ok !== true) {
		throw new Error(explain(String(payload.error ?? `http_${response.status}`), auth));
	}
	return payload;
}

/** `…/archives/C123ABC/p1730000000123456` → channel + ts. */
function fromPermalink(ref: string): { channel: string; ts: string } | undefined {
	const match = /\/archives\/([A-Z0-9]+)\/p(\d{10})(\d{6})/.exec(ref);
	return match ? { channel: match[1]!, ts: `${match[2]}.${match[3]}` } : undefined;
}

export function resolveTarget(channel: string | undefined, ts: string | undefined): { channel: string; ts: string } {
	const link = (ts ? fromPermalink(ts) : undefined) ?? (channel ? fromPermalink(channel) : undefined);
	if (link) return link;

	if (!channel || !ts) {
		throw new Error(
			"Need both `channel` (C…/D…/G…) and `ts` (e.g. 1730000000.123456), or a Slack message permalink in either argument. " +
				"Take both from conversations_history or conversations_search_messages output.",
		);
	}
	if (!/^[A-Z][A-Z0-9]{5,}$/.test(channel)) {
		throw new Error(
			`channel must be a Slack ID (C…/D…/G…), not "${channel}". Channel-name resolution lives in the MCP server's caches, ` +
				`not here — read the channel first, or pass a permalink.`,
		);
	}
	if (!/^\d{10}\.\d{6}$/.test(ts)) {
		throw new Error(`ts must look like 1730000000.123456, got "${ts}" (a Slack message URL also works).`);
	}
	return { channel, ts };
}

function text(value: string, details: Record<string, unknown>) {
	return { content: [{ type: "text" as const, text: value }], details };
}

const editMessage = defineTool({
	name: "slack_edit_message",
	label: "Edit Slack message",
	description:
		"Edit the text of a Slack message you posted (chat.update). Only your own messages are editable. " +
		"Pass channel + ts from conversations_history/search output, or a message permalink.",
	parameters: Type.Object({
		channel: Type.Optional(Type.String({ description: "Channel or DM ID (C…/D…/G…), or a Slack message permalink." })),
		ts: Type.Optional(Type.String({ description: "Message timestamp, e.g. 1730000000.123456, or a Slack message permalink." })),
		text: Type.String({ description: "Replacement message text. Slack markdown (*bold*, `code`, <url|label>) is used as-is." }),
	}),
	namespace: NAMESPACE,
	annotations: READ_WRITE,
	promptSnippet: "Edit or delete a Slack message you posted (chat.update / chat.delete)",
	async execute(_toolCallId, params, signal) {
		const { channel, ts } = resolveTarget(params.channel, params.ts);
		const result = await slackCall("chat.update", { channel, ts, text: params.text }, signal);
		const editedTs = typeof result.ts === "string" ? result.ts : ts;
		return text(`Edited ${channel} · ${editedTs}\n\n${params.text}`, { channel, ts: editedTs, edited: true });
	},
});

const deleteMessage = defineTool({
	name: "slack_delete_message",
	label: "Delete Slack message",
	description:
		"Delete a Slack message you posted (chat.delete). Only your own messages are deletable, and Slack keeps a " +
		"'This message was deleted' tombstone. Confirmation is handled by pi-guard.",
	parameters: Type.Object({
		channel: Type.Optional(Type.String({ description: "Channel or DM ID (C…/D…/G…), or a Slack message permalink." })),
		ts: Type.Optional(Type.String({ description: "Message timestamp, e.g. 1730000000.123456, or a Slack message permalink." })),
	}),
	namespace: NAMESPACE,
	annotations: DESTRUCTIVE,
	promptSnippet: "Delete a Slack message you posted",
	async execute(_toolCallId, params, signal) {
		const { channel, ts } = resolveTarget(params.channel, params.ts);
		await slackCall("chat.delete", { channel, ts }, signal);
		return text(`Deleted ${channel} · ${ts} (Slack leaves a "This message was deleted" tombstone).`, {
			channel,
			ts,
			deleted: true,
		});
	},
});

export default function (pi: ExtensionAPI) {
	pi.registerTool(editMessage);
	pi.registerTool(deleteMessage);
}
