/**
 * Safety gate — confirm destructive operations before they run.
 *
 * Intercepts `bash` tool calls that match clearly destructive patterns and asks
 * the user to confirm. In non-interactive mode the command is blocked. Ordinary
 * commands are never prompted.
 *
 * Paired with pi/rules.md, which documents the same policy for the model.
 */

import { isToolCallEventType, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DESTRUCTIVE: Array<{ pattern: RegExp; label: string }> = [
	{ pattern: /\brm\s+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|--recursive)/i, label: "recursive delete" },
	{ pattern: /\bgit\s+reset\s+--hard\b/i, label: "git reset --hard" },
	{ pattern: /\bgit\s+clean\s+-[a-z]*f/i, label: "git clean -f" },
	{ pattern: /\bgit\s+push\b[^\n]*(--force\b|-f\b)/i, label: "git force push" },
	{ pattern: /\b(DROP|TRUNCATE)\s+(TABLE|DATABASE|SCHEMA)\b/i, label: "destructive SQL" },
	{ pattern: /\bDELETE\s+FROM\s+\w+\s*(;|$)/im, label: "unfiltered SQL DELETE" },
	{ pattern: /\b(FLUSHALL|FLUSHDB)\b/i, label: "destructive Redis command" },
	{ pattern: /\b(dropdb|dropuser)\b/i, label: "destructive Postgres command" },
	{ pattern: /\bdd\s+[^\n]*\bof=/i, label: "raw write with dd" },
	{ pattern: /\bmkfs(\.\w+)?\b/i, label: "filesystem format" },
	{ pattern: /\bdocker(\s+compose)?\s+(system\s+prune|volume\s+prune|volume\s+rm|rm\s+-f)/i, label: "destructive docker command" },
	{ pattern: /\bdocker[\s-]compose\s+down\b[^\n]*(-v|--volumes)/i, label: "docker compose down --volumes" },
	{ pattern: /\bkubectl\s+delete\b/i, label: "kubectl delete" },
	{ pattern: /\bterraform\s+(destroy|apply\s+-auto-approve)/i, label: "destructive terraform command" },
	{ pattern: /\b(sudo\s+)?(shutdown|reboot|poweroff|halt)\b/i, label: "system power command" },
	{ pattern: /\bchmod\s+(-R\s+)?777\b/i, label: "world-writable chmod 777" },
];

export default function safetyExtension(pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		if (!isToolCallEventType("bash", event)) return undefined;

		const command = event.input.command;
		const hit = DESTRUCTIVE.find(({ pattern }) => pattern.test(command));
		if (!hit) return undefined;

		if (!ctx.hasUI) {
			return {
				block: true,
				reason: `Blocked destructive command (${hit.label}) — no UI to confirm`,
			};
		}

		const choice = await ctx.ui.select(
			`⚠️ Destructive command (${hit.label}):\n\n  ${command}\n\nAllow?`,
			["Yes", "No"],
		);

		if (choice !== "Yes") {
			return { block: true, reason: "Blocked by user" };
		}

		return undefined;
	});
}
