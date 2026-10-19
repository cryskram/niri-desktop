/**
 * Google Workspace for Pi — one extension, two halves.
 *
 * Accounts: `/google` adds Google accounts the same way `/login` picks a model
 * provider. Each sign-in goes through Google's own account chooser
 * (`prompt=select_account`) and lands in its own record, so a personal Gmail
 * account and a Workspace-managed account can sit side by side; `/google use`
 * switches the active one, and every tool accepts an `account` override.
 *
 * Tools: Sheets, Docs and Drive (tools.ts), all with the account's own token.
 * Credentials live outside the repo under `$PI_CODING_AGENT_DIR/google/`:
 * `client.json` is your OAuth client from the Google Cloud console and
 * `accounts.json` holds the tokens (both mode 0600).
 *
 * Declarative: loaded via modules/core.nix `programs.pi.coding-agent.extensions`
 * (the directory, so the sibling modules come along).
 */
import { readFileSync } from "node:fs";
import type {
	ExtensionAPI,
	ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";
import { ENDPOINT, googleJson, requireAccount } from "./api.ts";
import { signInWithGoogle } from "./login.ts";
import { DEFAULT_GROUPS, DEFAULT_SCOPES, parseScopes, SCOPE_GROUPS, scopeLabels } from "./oauth.ts";
import {
	accountEmails,
	clientPath,
	loadAccounts,
	loadClient,
	removeAccount,
	saveClient,
	setActive,
} from "./store.ts";
import { googleTools } from "./tools.ts";

const STATUS_KEY = "google";

const SUBCOMMANDS = ["add", "use", "rm", "status", "setup", "doctor", "scopes", "help"];

function statusText(): string | undefined {
	const store = loadAccounts();
	if (!store.active) return "○ none";
	const record = store.accounts[store.active];
	const kind = record?.hostedDomain ? "workspace" : "personal";
	return `● ${store.active} (${kind})${record?.needsReauth ? " !reauth" : ""}`;
}

function publishStatus(ctx: { ui: { setStatus(key: string, text: string | undefined): void } }): void {
	ctx.ui.setStatus(STATUS_KEY, statusText());
}

function pick(emails: string[], selector: string): string | undefined {
	const value = selector.trim();
	if (!value) return undefined;
	const index = Number.parseInt(value, 10);
	if (Number.isInteger(index) && index >= 1 && index <= emails.length) return emails[index - 1];
	return emails.find((email) => email === value) ?? emails.find((email) => email.startsWith(value));
}

function describeClient(): string {
	const client = loadClient();
	if (!client) return "No OAuth client configured. Run /google setup.";
	const suffix = client.clientId.split("-")[0] ?? "";
	return `OAuth client: ${suffix}…${client.clientSecret ? " (with secret)" : " (no secret — Desktop clients usually have one)"}\nStored at ${clientPath()}`;
}

/**
 * Dialog input is not clean text: terminal palette replies (OSC 4), cursor reports
 * and drag & drop quoting all arrive as if typed. `\u001b]4;65;rgb:…\u001b\\` landed
 * inside a pasted path once and the path was stored as the client ID.
 */
export function sanitizeInput(value: string): string {
	return value
		.replace(/\u001b\][^\u0007\u001b]*(?:\u0007|\u001b\\)?/g, "") // OSC … BEL | ESC \
		.replace(/\u001b\[[0-9;?]*[ -/]*[@-~]/g, "") // CSI
		.replace(/\u001b[@-Z\\-_]/g, "") // other escapes
		.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "") // C0 except tab
		.trim()
		.replace(/^['"]|['"]$/g, "")
		.replace(/\\(?=\s)/g, "") // /path\ with\ spaces
		.trim();
}

/** Every Google OAuth client ID ends this way; anything else is a paste accident. */
const CLIENT_ID_PATTERN = /[0-9]{6,}-[a-z0-9_-]+\.apps\.googleusercontent\.com/i;
const CLIENT_ID_EXACT = new RegExp(`^${CLIENT_ID_PATTERN.source}$`, "i");

async function readClientInput(value: string): Promise<unknown> {
	const cleaned = sanitizeInput(value);
	if (!cleaned) throw new Error("Nothing given.");

	if (cleaned.startsWith("{")) {
		try {
			return JSON.parse(cleaned);
		} catch (error) {
			throw new Error(`That looks like JSON but does not parse: ${(error as Error).message}`);
		}
	}

	const expanded = cleaned.startsWith("~") ? cleaned.replace("~", process.env.HOME ?? "") : cleaned;
	const isPath = expanded.includes("/") || expanded.toLowerCase().endsWith(".json");
	if (isPath) {
		try {
			return JSON.parse(readFileSync(expanded, "utf8"));
		} catch (error) {
			// Never fall back to "must be a bare client ID" here: that is exactly
			// how a path full of control sequences became the stored client ID and
			// produced Google's "OAuth client was not found" an hour later.
			throw new Error(`Could not read an OAuth client from "${expanded}": ${(error as Error).message}`);
		}
	}

	const candidate = cleaned.match(CLIENT_ID_PATTERN)?.[0] ?? cleaned;
	if (!CLIENT_ID_EXACT.test(candidate)) {
		throw new Error(
			`"${cleaned}" is neither a readable file path nor a Google OAuth client ID ` +
				`(expected something like 1234567890-abc.apps.googleusercontent.com).`,
		);
	}
	return { clientId: candidate };
}

async function setupClient(ctx: ExtensionCommandContext, value?: string): Promise<void> {
	const existing = loadClient();
	if (existing && !value) {
		const replace = await ctx.ui.confirm(
			"Replace the OAuth client?",
			`Currently configured: ${existing.clientId.slice(0, 12)}…. Only do this if you created a new client.`,
		);
		if (!replace) return;
	}
	let raw = value;
	if (!raw) {
		ctx.ui.notify(
			[
				"Create an OAuth client once, in the Google Cloud console:",
				"1. Create a project, then APIs & Services → Library: enable Google Drive, Sheets and Docs APIs.",
				"2. Google Auth Platform → Credentials → Create client → application type “Desktop app”.",
				"3. If the consent screen is in Testing, add your own addresses under Audience → Test users, and consider publishing it (Testing apps expire refresh tokens after 7 days).",
				"4. Paste the downloaded JSON below, or a path to it (or just the client ID).",
			].join("\n"),
			"info",
		);
		const answer = await ctx.ui.input("OAuth client JSON, path, or client ID", "~/Downloads/client_secret_….json");
		if (!answer) return;
		raw = answer;
	}
	let parsed: unknown;
	try {
		parsed = await readClientInput(raw);
	} catch (error) {
		ctx.ui.notify(`Could not read that client: ${(error as Error).message}`, "error");
		return;
	}
	try {
		const saved = saveClient(parsed);
		ctx.ui.notify(`Saved OAuth client ${saved.clientId.slice(0, 14)}… to ${clientPath()} (mode 0600).`, "info");
		const kind = (parsed as { web?: unknown }).web ? "web" : "installed";
		if (kind === "web") {
			ctx.ui.notify(
				"That is a Web-application client: it only accepts redirect URIs registered exactly, so add http://127.0.0.1:8765/callback under Authorized redirect URIs (a Desktop-app client would take any loopback port).",
				"warning",
			);
		}
	} catch (error) {
		ctx.ui.notify((error as Error).message, "error");
	}
}

async function addAccount(ctx: ExtensionCommandContext, args: string): Promise<void> {
	if (!loadClient()) {
		ctx.ui.notify("No OAuth client yet — let's set that up first.", "warning");
		await setupClient(ctx);
		if (!loadClient()) return;
	}
	let scopes = DEFAULT_SCOPES;
	let loginHint: string | undefined;
	for (const token of args.split(/\s+/).filter(Boolean)) {
		if (token.startsWith("--scopes=")) {
			try {
				// parseScopes returns the named groups/URLs only; the base identity
				// scopes are re-added in signInWithGoogle, which is where they matter.
				scopes = parseScopes(token.slice("--scopes=".length));
			} catch (error) {
				ctx.ui.notify((error as Error).message, "error");
				return;
			}
		} else if (token.includes("@")) {
			loginHint = token;
		}
	}
	try {
		const record = await signInWithGoogle(ctx, { scopes, loginHint });
		const kind = record.hostedDomain ? `Workspace-managed (${record.hostedDomain})` : "personal";
		ctx.ui.notify(
			`Connected ${record.email} — ${kind}, scopes: ${scopeLabels(record.scopes)}. It is now the active account.`,
			"info",
		);
	} catch (error) {
		ctx.ui.notify(`Sign-in failed: ${(error as Error).message}`, "error");
	}
	publishStatus(ctx);
}

async function doctor(ctx: ExtensionCommandContext): Promise<void> {
	const emails = accountEmails();
	if (!emails.length) {
		ctx.ui.notify("No accounts connected. Run /google add.", "warning");
		return;
	}
	const lines: string[] = [];
	for (const email of emails) {
		const { record } = requireAccount(email);
		try {
			const info = await googleJson<{ email?: string }>({ email, url: ENDPOINT.userinfo });
			const match = info.email === email ? "ok" : `token email is ${info.email ?? "?"}`;
			lines.push(`✔ ${email} — ${match}; scopes: ${scopeLabels(record.scopes)}`);
		} catch (error) {
			lines.push(`✖ ${email} — ${(error as Error).message}`);
		}
	}
	ctx.ui.notify(lines.join("\n"), lines.some((line) => line.startsWith("✖")) ? "warning" : "info");
}

async function menu(ctx: ExtensionCommandContext): Promise<void> {
	for (;;) {
		const store = loadAccounts();
		const emails = Object.keys(store.accounts).sort();
		const options = [
			...emails.map((email) => {
				const record = store.accounts[email]!;
				const marks = [
					email === store.active ? "active" : undefined,
					record.hostedDomain ? `workspace: ${record.hostedDomain}` : "personal",
					record.needsReauth ? "needs re-auth" : undefined,
				].filter(Boolean);
				return `${email}  —  ${marks.join(", ")}`;
			}),
			"＋ Add another Google account",
			"🔁 Re-authenticate an account",
			"🗑  Remove an account",
			"⚙️  OAuth client setup",
			"🩺 Doctor: verify every token",
		];
		const choice = await ctx.ui.select(emails.length ? "Google accounts" : "No Google account connected yet", options);
		if (!choice) return;

		if (choice.startsWith("＋")) {
			await addAccount(ctx, "");
			continue;
		}
		if (choice.startsWith("🔁")) {
			const email = await ctx.ui.select("Re-authenticate which account?", emails);
			if (!email) continue;
			await addAccount(ctx, email);
			continue;
		}
		if (choice.startsWith("🗑")) {
			const email = await ctx.ui.select("Remove which account?", emails);
			if (!email) continue;
			if (await ctx.ui.confirm("Remove account?", `${email} will be signed out of Pi. Google keeps the app authorized — revoke it in your Google account if you want that undone.`)) {
				setActive(emails.find((candidate) => candidate !== email) ?? "");
				removeAccount(email);
				ctx.ui.notify(`Removed ${email}.`, "info");
				publishStatus(ctx);
			}
			continue;
		}
		if (choice.startsWith("⚙️")) {
			await setupClient(ctx);
			continue;
		}
		if (choice.startsWith("🩺")) {
			await doctor(ctx);
			continue;
		}

		const email = choice.split("  —  ")[0]!;
		const action = await ctx.ui.select(email, [
			`Make active`,
			`Re-authenticate`,
			`Show scopes and token state`,
			`Remove`,
			"← Back",
		]);
		if (!action || action === "← Back") continue;
		if (action === "Make active") {
			setActive(email);
			ctx.ui.notify(`${email} is now the active Google account.`, "info");
			publishStatus(ctx);
		} else if (action === "Re-authenticate") {
			await addAccount(ctx, email);
		} else if (action === "Show scopes and token state") {
			const record = store.accounts[email]!;
			ctx.ui.notify(
				[
					`${email}${record.hostedDomain ? ` — Workspace-managed (${record.hostedDomain})` : " — personal"}`,
					`scopes: ${scopeLabels(record.scopes)}`,
					`refresh token: ${record.refreshToken ? "stored" : "MISSING — re-authenticate"}`,
					`access token: ${record.expiresAt && record.expiresAt > Date.now() ? `valid until ${new Date(record.expiresAt).toISOString()}` : "expired (refreshes on use)"}`,
					`added: ${record.addedAt}`,
				].join("\n"),
				record.needsReauth ? "warning" : "info",
			);
		} else if (action === "Remove") {
			removeAccount(email);
			ctx.ui.notify(`Removed ${email}.`, "info");
			publishStatus(ctx);
		}
	}
}

async function runCommand(rawArgs: string, ctx: ExtensionCommandContext): Promise<void> {
	const args = rawArgs.trim();
	const [verb = "", ...rest] = args.split(/\s+/);
	const remainder = args.slice(verb.length).trim();
	const emails = accountEmails();

	switch (verb) {
		case "":
			await menu(ctx);
			return;
		case "help":
			ctx.ui.notify(
				[
					"/google                      account menu",
					"/google add [--scopes=a,b] [email-hint]",
					`/google use <email|number>   switch the active account`,
					"/google rm <email|number>",
					"/google status               accounts and token state",
					"/google setup [json|path]    OAuth client credentials",
					"/google doctor               verify every token against Google",
					"/google scopes               available scope groups",
				].join("\n"),
				"info",
			);
			return;
		case "status": {
			const store = loadAccounts();
			const lines = Object.keys(store.accounts)
				.sort()
				.map((email) => {
					const record = store.accounts[email]!;
					const active = email === store.active ? " ●" : " ○";
					return `${active} ${email}${record.hostedDomain ? ` (workspace: ${record.hostedDomain})` : " (personal)"}${record.needsReauth ? " — needs re-auth" : ""}`;
				});
			ctx.ui.notify(`${lines.length ? lines.join("\n") : "No accounts connected."}\n\n${describeClient()}`, "info");
			return;
		}
		case "add":
			await addAccount(ctx, remainder);
			return;
		case "use": {
			const email = pick(emails, remainder);
			if (!email) {
				ctx.ui.notify(`Unknown account. Connected: ${emails.join(", ") || "none"}`, "error");
				return;
			}
			setActive(email);
			ctx.ui.notify(`${email} is now the active Google account.`, "info");
			publishStatus(ctx);
			return;
		}
		case "rm": {
			const email = pick(emails, remainder);
			if (!email) {
				ctx.ui.notify(`Unknown account. Connected: ${emails.join(", ") || "none"}`, "error");
				return;
			}
			if (await ctx.ui.confirm("Remove account?", `${email} will be signed out of Pi.`)) {
				removeAccount(email);
				ctx.ui.notify(`Removed ${email}.`, "info");
				publishStatus(ctx);
			}
			return;
		}
		case "setup":
			await setupClient(ctx, rest.join(" ") || undefined);
			return;
		case "doctor":
			await doctor(ctx);
			return;
		case "scopes":
			ctx.ui.notify(
				`Scope groups:\n${Object.entries(SCOPE_GROUPS)
					.map(([name, url]) => `  ${name} — ${url}`)
					.join("\n")}\n\nDefault: ${DEFAULT_GROUPS.join(", ")}\nExample: /google add --scopes=drive,sheets,docs,gmail,calendar`,
				"info",
			);
			return;
		default:
			ctx.ui.notify(`Unknown subcommand "${verb}". Try /google help.`, "error");
	}
}

export default function googleWorkspace(pi: ExtensionAPI): void {
	for (const tool of googleTools) pi.registerTool(tool);

	pi.registerCommand("google", {
		description: "Google accounts: add, switch, re-authenticate (Sheets · Docs · Drive)",
		getArgumentCompletions: (prefix) =>
			SUBCOMMANDS.filter((name) => name.startsWith(prefix.trim())).map((name) => ({
				value: name,
				label: name,
			})),
		handler: runCommand,
	});

	pi.on("session_start", (_event, ctx) => {
		publishStatus(ctx);
	});

	pi.on("session_shutdown", (_event, ctx) => {
		ctx.ui.setStatus(STATUS_KEY, undefined);
	});
}
