/**
 * Google account store — OAuth client credentials plus one token record per account.
 *
 * Lives outside the repo at `$PI_CODING_AGENT_DIR/google/` (dir 0700):
 *   client.json    the user's own OAuth client, from the Google Cloud console
 *   accounts.json  per-account tokens, granted scopes, and the active email
 *
 * Never printed, never committed: both files are written at mode 0600.
 */
import { chmodSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export type ClientCredentials = { clientId: string; clientSecret?: string };

export type AccountRecord = {
	email: string;
	name?: string;
	/** Google's `hd` claim — set only for Workspace-managed accounts. */
	hostedDomain?: string;
	refreshToken?: string;
	accessToken?: string;
	/** Epoch ms; the access token is treated as dead 60s before this. */
	expiresAt?: number;
	scopes: string[];
	addedAt: string;
	/** Set when a refresh was rejected: the account needs an interactive sign-in. */
	needsReauth?: boolean;
};

export type AccountStore = { active?: string; accounts: Record<string, AccountRecord> };

export function googleDir(): string {
	return join(process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"), "google");
}

export function clientPath(): string {
	return join(googleDir(), "client.json");
}

export function accountsPath(): string {
	return join(googleDir(), "accounts.json");
}

function writePrivate(path: string, text: string): void {
	mkdirSync(googleDir(), { recursive: true, mode: 0o700 });
	writeFileSync(path, text, { mode: 0o600 });
	chmodSync(path, 0o600);
}

function readJson(path: string): unknown {
	try {
		return JSON.parse(readFileSync(path, "utf8"));
	} catch {
		return undefined;
	}
}

/** Accepts `{clientId, clientSecret}`, Google's downloaded `{"installed":{...}}` / `{"web":{...}}`, or nothing. */
function parseClient(raw: unknown): ClientCredentials | undefined {
	if (!raw || typeof raw !== "object") return undefined;
	const outer = raw as Record<string, unknown>;
	const inner = (outer.installed ?? outer.web ?? outer) as Record<string, unknown>;
	const id = inner.client_id ?? inner.clientId;
	if (typeof id !== "string" || !id) return undefined;
	const secret = inner.client_secret ?? inner.clientSecret;
	return { clientId: id, clientSecret: typeof secret === "string" && secret ? secret : undefined };
}

export function loadClient(): ClientCredentials | undefined {
	const env = process.env.GOOGLE_OAUTH_CLIENT_ID;
	if (env) return { clientId: env, clientSecret: process.env.GOOGLE_OAUTH_CLIENT_SECRET || undefined };
	return parseClient(readJson(clientPath()));
}

export function saveClient(raw: unknown): ClientCredentials {
	const creds = parseClient(raw);
	if (!creds) {
		throw new Error(
			"No client_id found. Paste the JSON you downloaded from Google Cloud (or just the client ID, then the secret).",
		);
	}
	writePrivate(clientPath(), `${JSON.stringify(creds, null, 2)}\n`);
	return creds;
}

export function loadAccounts(): AccountStore {
	const raw = readJson(accountsPath()) as Partial<AccountStore> | undefined;
	const accounts =
		raw?.accounts && typeof raw.accounts === "object" ? (raw.accounts as AccountStore["accounts"]) : {};
	const active = typeof raw?.active === "string" && accounts[raw.active] ? raw.active : Object.keys(accounts)[0];
	return { active, accounts };
}

export function saveAccounts(store: AccountStore): void {
	writePrivate(accountsPath(), `${JSON.stringify(store, null, 2)}\n`);
}

export function upsertAccount(record: AccountRecord, options: { makeActive?: boolean } = {}): AccountStore {
	const store = loadAccounts();
	store.accounts[record.email] = record;
	if (options.makeActive || !store.active) store.active = record.email;
	saveAccounts(store);
	return store;
}

export function setActive(email: string): AccountStore {
	const store = loadAccounts();
	if (!store.accounts[email]) throw new Error(`Unknown account ${email}`);
	store.active = email;
	saveAccounts(store);
	return store;
}

export function removeAccount(email: string): AccountStore {
	const store = loadAccounts();
	delete store.accounts[email];
	if (store.active === email) store.active = Object.keys(store.accounts)[0];
	saveAccounts(store);
	return store;
}

export function accountEmails(): string[] {
	return Object.keys(loadAccounts().accounts).sort();
}
