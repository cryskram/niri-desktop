/**
 * Interactive sign-in — one Google account per run, chosen in Google's own
 * account picker when `prompt=select_account` is set.
 *
 * Two capture paths: the loopback listener (normal case, browser opens on this
 * machine) and pasting the redirected URL (no listener, or the browser lives
 * somewhere else).
 */
import type { ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import {
	BASE_SCOPES,
	buildAuthUrl,
	claimsFromIdToken,
	createPkce,
	DEFAULT_SCOPES,
	describeAuthError,
	exchangeCode,
	openInBrowser,
	openLoopback,
	scopeLabels,
	type Loopback,
} from "./oauth.ts";
import { loadClient, upsertAccount, type AccountRecord } from "./store.ts";

function codeFromInput(input: string): string {
	const value = input.trim();
	if (!value) throw new Error("Nothing pasted.");
	if (value.includes("://") || value.startsWith("http")) {
		const url = new URL(value);
		const error = url.searchParams.get("error");
		if (error) throw new Error(describeAuthError(error, url.searchParams.get("error_description")));
		const code = url.searchParams.get("code");
		if (!code) throw new Error("That URL has no ?code= parameter.");
		return code;
	}
	return value;
}

async function pasteCode(ctx: ExtensionCommandContext, redirectUri: string): Promise<string> {
	const input = await ctx.ui.input(
		"Paste the redirected URL",
		`${redirectUri}?code=… (or the code alone)`,
	);
	if (input === undefined) throw new Error("Sign-in cancelled.");
	return codeFromInput(input);
}

export async function signInWithGoogle(
	ctx: ExtensionCommandContext,
	options: { scopes?: string[]; loginHint?: string; makeActive?: boolean } = {},
): Promise<AccountRecord> {
	const client = loadClient();
	if (!client) throw new Error("No OAuth client configured yet. Run /google setup first.");
	// openid + email are what name the account (ID token claims, then userinfo),
	// so they are added back whatever the caller asked for: a `--scopes=` list
	// without them signs in successfully and then cannot say who signed in.
	const requested = options.scopes?.length ? options.scopes : DEFAULT_SCOPES;
	const scopes = [...new Set([...BASE_SCOPES, ...requested])];
	const state = crypto.randomUUID();
	const { verifier, challenge } = await createPkce();

	let loopback: Loopback | undefined;
	try {
		loopback = await openLoopback(state);
	} catch {
		loopback = undefined;
	}
	const redirectUri = loopback?.redirectUri ?? "http://127.0.0.1:8765/callback";
	const url = buildAuthUrl({ client, redirectUri, scopes, state, challenge, loginHint: options.loginHint });

	const opened = openInBrowser(url);
	ctx.ui.notify(
		`${opened ? "Opened Google sign-in in your browser" : "Open this URL to sign in"} — choose the account you want to connect:\n${url}`,
		"info",
	);

	try {
		let code: string;
		if (loopback) {
			try {
				code = await loopback.waitForCode();
			} catch (error) {
				ctx.ui.notify(`${(error as Error).message} Falling back to copy/paste.`, "warning");
				code = await pasteCode(ctx, redirectUri);
			}
		} else {
			code = await pasteCode(ctx, redirectUri);
		}

		const tokens = await exchangeCode({ client, code, verifier, redirectUri });
		const claims = claimsFromIdToken(tokens.id_token);
		let email = claims.email;
		let identityError: string | undefined;
		if (!email) {
			const response = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
				headers: { authorization: `Bearer ${tokens.access_token}` },
			});
			const info = (await response.json().catch(() => ({}))) as {
				email?: string;
				name?: string;
				error?: string | { message?: string };
			};
			email = info.email;
			claims.name ??= info.name;
			if (!email) {
				identityError =
					typeof info.error === "string"
						? info.error
						: (info.error?.message ?? `userinfo returned ${response.status}`);
			}
		}
		if (!email) {
			// Happens when the authorization request omitted openid/email: the token
			// exchange succeeds, then nothing identifies the account.
			throw new Error(
				`Signed in, but Google returned no email address (${identityError ?? "no id_token, and userinfo had no email"}; granted scopes: ${scopeLabels(tokens.scope ? tokens.scope.split(" ") : scopes)}). ` +
					`Run /google add again — openid and email are now always requested.`,
			);
		}

		const record: AccountRecord = {
			email,
			name: claims.name,
			hostedDomain: claims.hd,
			refreshToken: tokens.refresh_token,
			accessToken: tokens.access_token,
			expiresAt: Date.now() + tokens.expires_in * 1000,
			scopes: tokens.scope ? tokens.scope.split(" ") : scopes,
			addedAt: new Date().toISOString(),
		};
		if (!record.refreshToken) {
			ctx.ui.notify(
				"Google did not return a refresh token — this account will need re-authentication when the hour is up. Re-run /google add to try again.",
				"warning",
			);
		}
		const notGranted = scopes.filter((scope) => !record.scopes.includes(scope));
		if (notGranted.length) {
			ctx.ui.notify(
				`Google did not grant: ${scopeLabels(notGranted)}. Tools needing those will fail with a scope error until the consent screen or the admin allows them.`,
				"warning",
			);
		}
		upsertAccount(record, { makeActive: options.makeActive ?? true });
		return record;
	} finally {
		loopback?.close();
	}
}
