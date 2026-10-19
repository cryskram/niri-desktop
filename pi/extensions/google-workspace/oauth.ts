/**
 * Google OAuth 2.0 — authorization code + PKCE over a loopback redirect.
 *
 * `access_type=offline` with `prompt=consent select_account` forces both the
 * account chooser and a refresh token on every sign-in, which is what makes
 * several Google accounts (personal and Workspace-managed) first-class here:
 * each sign-in lands in its own record keyed by the account's email.
 */
import { spawn } from "node:child_process";
import { createServer, type Server } from "node:http";
import type { ClientCredentials } from "./store.ts";

export const AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth";
export const TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";

/** Scope groups, so `/google add --scopes=drive,sheets` stays readable. */
export const SCOPE_GROUPS: Record<string, string> = {
	drive: "https://www.googleapis.com/auth/drive",
	sheets: "https://www.googleapis.com/auth/spreadsheets",
	docs: "https://www.googleapis.com/auth/documents",
	gmail: "https://www.googleapis.com/auth/gmail.readonly",
	"gmail.send": "https://www.googleapis.com/auth/gmail.send",
	calendar: "https://www.googleapis.com/auth/calendar",
	tasks: "https://www.googleapis.com/auth/tasks",
};

export const BASE_SCOPES = ["openid", "email", "profile"];
export const DEFAULT_GROUPS = ["drive", "sheets", "docs"];
export const DEFAULT_SCOPES = [...BASE_SCOPES, ...DEFAULT_GROUPS.map((g) => SCOPE_GROUPS[g]!)];

export type TokenResponse = {
	access_token: string;
	refresh_token?: string;
	expires_in: number;
	scope?: string;
	id_token?: string;
	token_type?: string;
};

export type GoogleAuthError = { error: string; error_description?: string };

function base64Url(bytes: Uint8Array): string {
	return Buffer.from(bytes).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function createPkce(): Promise<{ verifier: string; challenge: string }> {
	const verifier = base64Url(crypto.getRandomValues(new Uint8Array(32)));
	const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
	return { verifier, challenge: base64Url(new Uint8Array(digest)) };
}

export function buildAuthUrl(opts: {
	client: ClientCredentials;
	redirectUri: string;
	scopes: string[];
	state: string;
	challenge: string;
	loginHint?: string;
}): string {
	const params = new URLSearchParams({
		client_id: opts.client.clientId,
		redirect_uri: opts.redirectUri,
		response_type: "code",
		scope: opts.scopes.join(" "),
		code_challenge: opts.challenge,
		code_challenge_method: "S256",
		state: opts.state,
		access_type: "offline",
		prompt: "consent select_account",
		include_granted_scopes: "true",
	});
	if (opts.loginHint) params.set("login_hint", opts.loginHint);
	return `${AUTH_ENDPOINT}?${params.toString()}`;
}

export type Loopback = {
	port: number;
	redirectUri: string;
	/** Resolves with the authorization code, rejects on error/timeout/cancel. */
	waitForCode: (signal?: AbortSignal) => Promise<string>;
	close: () => void;
};

/**
 * Binding the loopback port *before* building the auth URL keeps the redirect
 * URI exact, which Web-application OAuth clients require. Desktop clients
 * accept any loopback port, so the fallback search is safe either way.
 */
export async function openLoopback(state: string, preferredPort = 8765, attempts = 24): Promise<Loopback> {
	let server: Server | undefined;
	let port = 0;

	for (let i = 0; i < attempts && !server; i++) {
		const candidate = preferredPort + i;
		const bound = await new Promise<Server | undefined>((resolve) => {
			const candidateServer = createServer();
			candidateServer.once("error", () => resolve(undefined));
			candidateServer.listen(candidate, "127.0.0.1", () => resolve(candidateServer));
		});
		if (bound) {
			server = bound;
			port = candidate;
		}
	}
	if (!server) throw new Error(`Could not bind a loopback port on 127.0.0.1:${preferredPort}-${preferredPort + attempts - 1}`);

	let settle: { resolve: (code: string) => void; reject: (err: Error) => void } | undefined;
	const codePromise = new Promise<string>((resolve, reject) => {
		settle = { resolve, reject };
	});

	server.on("request", (req, res) => {
		const url = new URL(req.url ?? "/", `http://127.0.0.1:${port}`);
		const reply = (title: string, body: string) => {
			res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
			res.end(
				`<!doctype html><meta charset="utf-8"><title>${title}</title>` +
					`<body style="font:15px system-ui;margin:3rem;max-width:40rem;color:#111"><h2>${title}</h2><p>${body}</p></body>`,
			);
		};
		if (url.pathname !== "/callback") {
			res.writeHead(404).end("Not found");
			return;
		}
		const error = url.searchParams.get("error");
		const code = url.searchParams.get("code");
		if (error) {
			reply("Sign-in failed", `Google returned <code>${error}</code>. You can close this tab.`);
			settle?.reject(new Error(describeAuthError(error, url.searchParams.get("error_description"))));
			return;
		}
		if (url.searchParams.get("state") !== state) {
			reply("Ignored", "State mismatch — this tab was not opened by Pi.");
			return;
		}
		if (!code) {
			reply("Waiting", "No authorization code in this redirect.");
			return;
		}
		reply("Connected to Pi", "You can close this tab and go back to Pi.");
		settle?.resolve(code);
	});

	const close = () => {
		try {
			server.close();
		} catch {
			/* already closed */
		}
	};

	return {
		port,
		redirectUri: `http://127.0.0.1:${port}/callback`,
		close,
		waitForCode: (signal?: AbortSignal) =>
			new Promise<string>((resolve, reject) => {
				const timer = setTimeout(() => reject(new Error("Timed out after 5 minutes waiting for the browser.")), 300_000);
				const onAbort = () => reject(new Error("Sign-in cancelled."));
				signal?.addEventListener("abort", onAbort, { once: true });
				codePromise.then(
					(value) => {
						clearTimeout(timer);
						signal?.removeEventListener("abort", onAbort);
						resolve(value);
					},
					(error) => {
						clearTimeout(timer);
						signal?.removeEventListener("abort", onAbort);
						reject(error);
					},
				);
			}),
	};
}

export function openInBrowser(url: string): boolean {
	const command =
		process.platform === "darwin" ? "open" : process.platform === "win32" ? "cmd" : "xdg-open";
	const args = process.platform === "win32" ? ["/c", "start", "", url] : [url];
	try {
		const child = spawn(command, args, { detached: true, stdio: "ignore" });
		// A missing opener (headless session, no xdg-open) emits an async 'error';
		// without a listener that would take the whole pi process down.
		child.on("error", () => {});
		child.unref();
		return true;
	} catch {
		return false;
	}
}

async function postToken(body: URLSearchParams, signal?: AbortSignal): Promise<TokenResponse> {
	const response = await fetch(TOKEN_ENDPOINT, {
		method: "POST",
		headers: { "content-type": "application/x-www-form-urlencoded" },
		body,
		signal,
	});
	const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
	if (!response.ok) {
		throw new Error(describeTokenError(payload));
	}
	return payload as unknown as TokenResponse;
}

export async function exchangeCode(opts: {
	client: ClientCredentials;
	code: string;
	verifier: string;
	redirectUri: string;
	signal?: AbortSignal;
}): Promise<TokenResponse> {
	const body = new URLSearchParams({
		code: opts.code,
		client_id: opts.client.clientId,
		code_verifier: opts.verifier,
		grant_type: "authorization_code",
		redirect_uri: opts.redirectUri,
	});
	if (opts.client.clientSecret) body.set("client_secret", opts.client.clientSecret);
	return postToken(body, opts.signal);
}

export async function refreshAccessToken(opts: {
	client: ClientCredentials;
	refreshToken: string;
	signal?: AbortSignal;
}): Promise<TokenResponse> {
	const body = new URLSearchParams({
		client_id: opts.client.clientId,
		refresh_token: opts.refreshToken,
		grant_type: "refresh_token",
	});
	if (opts.client.clientSecret) body.set("client_secret", opts.client.clientSecret);
	return postToken(body, opts.signal);
}

/** Identity claims of an ID token. `hd` presence marks a Workspace-managed account. */
export function claimsFromIdToken(idToken: string | undefined): {
	email?: string;
	name?: string;
	hd?: string;
	sub?: string;
} {
	if (!idToken) return {};
	try {
		const payload = idToken.split(".")[1];
		if (!payload) return {};
		const json = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as Record<string, unknown>;
		return {
			email: typeof json.email === "string" ? json.email : undefined,
			name: typeof json.name === "string" ? json.name : undefined,
			hd: typeof json.hd === "string" ? json.hd : undefined,
			sub: typeof json.sub === "string" ? json.sub : undefined,
		};
	} catch {
		return {};
	}
}

export function describeAuthError(error: string, description?: string | null): string {
	const suffix = description ? ` (${description})` : "";
	switch (error) {
		case "access_denied":
			return `Google refused the sign-in${suffix}. If this is a Workspace account, an admin may block this OAuth client.`;
		case "redirect_uri_mismatch":
			return "Redirect URI not registered on the OAuth client. Add http://127.0.0.1:8765/callback under Authorized redirect URIs.";
		case "invalid_client":
			return "Google rejected the OAuth client. Re-run /google setup with the client ID and secret.";
		default:
			return `Google returned ${error}${suffix}.`;
	}
}

export function describeTokenError(payload: Record<string, unknown>): string {
	const error = typeof payload.error === "string" ? payload.error : "unknown_error";
	const description =
		typeof payload.error_description === "string" ? payload.error_description : undefined;
	const suffix = description ? ` — ${description}` : "";
	switch (error) {
		case "invalid_grant":
			return (
				"Google rejected the token (invalid_grant). The usual causes: the refresh token expired (personal Gmail projects in " +
				`Testing status expire them after 7 days — publish the OAuth consent screen or re-authenticate), it was revoked, or the consent was reset.${suffix}`
			);
		case "invalid_client":
			return `Google rejected the OAuth client (check /google setup).${suffix}`;
		case "redirect_uri_mismatch":
			return "Redirect URI mismatch: register http://127.0.0.1:8765/callback on the OAuth client, or use a Desktop-application client.";
		default:
			return `Google token endpoint error: ${error}${suffix}`;
	}
}

export function parseScopes(value: string): string[] {
	const out: string[] = [];
	for (const raw of value.split(/[,\s]+/).filter(Boolean)) {
		if (raw.startsWith("https://")) out.push(raw);
		else if (SCOPE_GROUPS[raw]) out.push(SCOPE_GROUPS[raw]!);
		else throw new Error(`Unknown scope group "${raw}". Known: ${Object.keys(SCOPE_GROUPS).join(", ")}`);
	}
	return out;
}

/** Short group names for UI, e.g. "drive, sheets" — derived from granted scope URLs. */
export function scopeLabels(scopes: string[]): string {
	const known = Object.entries(SCOPE_GROUPS)
		.filter(([, url]) => scopes.includes(url))
		.map(([name]) => name);
	const extra = scopes.filter((s) => !Object.values(SCOPE_GROUPS).includes(s) && !BASE_SCOPES.includes(s));
	return [...known, ...extra.map((s) => s.replace("https://www.googleapis.com/auth/", ""))].join(", ");
}
