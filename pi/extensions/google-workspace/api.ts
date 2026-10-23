/**
 * Google API layer — one access token per account, request helpers, and the
 * small amount of Drive/Docs knowledge the tools need (file references by ID,
 * URL, or name; Doc text and outline extraction; export MIME choices).
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { refreshAccessToken } from "./oauth.ts";
import { loadAccounts, loadClient, saveAccounts, type AccountRecord } from "./store.ts";

export const ENDPOINT = {
	sheets: "https://sheets.googleapis.com/v4/spreadsheets",
	docs: "https://docs.googleapis.com/v1/documents",
	drive: "https://www.googleapis.com/drive/v3",
	upload: "https://www.googleapis.com/upload/drive/v3",
	userinfo: "https://www.googleapis.com/oauth2/v3/userinfo",
} as const;

export const MIME = {
	folder: "application/vnd.google-apps.folder",
	doc: "application/vnd.google-apps.document",
	sheet: "application/vnd.google-apps.spreadsheet",
	slides: "application/vnd.google-apps.presentation",
	script: "application/vnd.google-apps.script",
} as const;

export const GOOGLE_NATIVE = new Set<string>([MIME.doc, MIME.sheet, MIME.slides, MIME.script]);

export type ResolvedAccount = { email: string; record: AccountRecord };

/** Resolve the account param: an explicit email, or the active account. */
export function requireAccount(ref?: string): ResolvedAccount {
	const store = loadAccounts();
	const email = ref?.trim() || store.active;
	if (!email) {
		throw new Error("No Google account is connected. Run /google in Pi to add one.");
	}
	const record = store.accounts[email];
	if (!record) {
		const known = Object.keys(store.accounts).sort();
		throw new Error(
			known.length
				? `Unknown Google account "${email}". Connected: ${known.join(", ")}`
				: `No Google account is connected. Run /google to add one.`,
		);
	}
	return { email, record };
}

const inflightRefresh = new Map<string, Promise<AccountRecord>>();

export async function forceRefresh(email: string, signal?: AbortSignal): Promise<AccountRecord> {
	const existing = inflightRefresh.get(email);
	if (existing) return existing;
	const task = (async () => {
		const client = loadClient();
		if (!client) throw new Error("No OAuth client configured. Run /google setup.");
		const store = loadAccounts();
		const record = store.accounts[email];
		if (!record) throw new Error(`Unknown Google account "${email}".`);
		if (!record.refreshToken) {
			record.needsReauth = true;
			saveAccounts(store);
			throw new Error(`${email} has no refresh token. Run /google and re-authenticate that account.`);
		}
		try {
			const tokens = await refreshAccessToken({ client, refreshToken: record.refreshToken, signal });
			record.accessToken = tokens.access_token;
			record.expiresAt = Date.now() + tokens.expires_in * 1000;
			if (tokens.refresh_token) record.refreshToken = tokens.refresh_token;
			if (tokens.scope) record.scopes = tokens.scope.split(" ");
			record.needsReauth = false;
			saveAccounts(store);
			return record;
		} catch (error) {
			record.needsReauth = true;
			saveAccounts(store);
			throw error;
		}
	})().finally(() => inflightRefresh.delete(email));
	inflightRefresh.set(email, task);
	return task;
}

export async function accessToken(email: string, signal?: AbortSignal): Promise<string> {
	const { record } = requireAccount(email);
	if (record.accessToken && (record.expiresAt ?? 0) > Date.now() + 60_000) return record.accessToken;
	return (await forceRefresh(email, signal)).accessToken!;
}

export type FetchOptions = {
	email: string;
	url: string;
	method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
	body?: unknown;
	headers?: Record<string, string>;
	signal?: AbortSignal;
};

async function describeHttpError(response: Response): Promise<string> {
	const text = await response.text().catch(() => "");
	let detail = text.slice(0, 600);
	try {
		const json = JSON.parse(text) as { error?: { message?: string; status?: string; errors?: unknown } };
		if (json.error?.message) detail = json.error.message;
	} catch {
		/* not JSON: keep the raw slice */
	}
	const hints: string[] = [];
	if (response.status === 401) hints.push("token rejected — run /google and re-authenticate this account");
	if (response.status === 403) {
		const lower = detail.toLowerCase();
		if (lower.includes("insufficient") || lower.includes("scope")) {
			hints.push("the account is missing a scope for this call — re-authenticate with /google add --scopes=…");
		}
		if (lower.includes("rate") || lower.includes("quota")) hints.push("quota exceeded; retry later");
		if (lower.includes("has not been used") || lower.includes("disabled")) hints.push("enable the API for that service in the Google Cloud project");
	}
	if (response.status === 404) hints.push("not found, or the signed-in account cannot see it");
	if (response.status === 400 && detail.toLowerCase().includes("parse")) hints.push("check the ID/range/body format");
	return `${response.status} ${response.statusText}: ${detail}${hints.length ? ` [${hints.join("; ")}]` : ""}`;
}

async function authorizedFetch(options: FetchOptions, retry = true): Promise<Response> {
	const token = await accessToken(options.email, options.signal);
	const response = await fetch(options.url, {
		method: options.method ?? "GET",
		headers: {
			authorization: `Bearer ${token}`,
			...(options.body !== undefined ? { "content-type": "application/json" } : {}),
			...options.headers,
		},
		body: options.body === undefined ? undefined : JSON.stringify(options.body),
		signal: options.signal,
	});
	if (response.status === 401 && retry) {
		await forceRefresh(options.email, options.signal);
		return authorizedFetch(options, false);
	}
	if (!response.ok) throw new Error(await describeHttpError(response));
	return response;
}

export async function googleJson<T = Record<string, unknown>>(options: FetchOptions): Promise<T> {
	const response = await authorizedFetch(options);
	const text = await response.text();
	if (!text) return {} as T;
	return JSON.parse(text) as T;
}

export async function googleBytes(options: FetchOptions): Promise<ArrayBuffer> {
	const response = await authorizedFetch(options);
	return response.arrayBuffer();
}

/* ------------------------------------------------------------------ *
 * File references: raw id, a Google URL, or a name to search for
 * ------------------------------------------------------------------ */

const ID_PATTERN = /^[a-zA-Z0-9_-]{20,}$/;

export function extractFileId(ref: string): string | undefined {
	const trimmed = ref.trim();
	const inUrl = trimmed.match(/\/d\/([a-zA-Z0-9_-]{20,})/) ?? trimmed.match(/[?&]id=([a-zA-Z0-9_-]{20,})/);
	if (inUrl?.[1]) return inUrl[1];
	if (ID_PATTERN.test(trimmed)) return trimmed;
	return undefined;
}

export type DriveFile = {
	id: string;
	name: string;
	mimeType: string;
	modifiedTime?: string;
	owners?: Array<{ emailAddress?: string; displayName?: string }>;
	parents?: string[];
	webViewLink?: string;
	size?: string;
};

/** Drive query syntax with escaping, so names with apostrophes do not break. */
export function driveQuery(parts: { name?: string; mimeType?: string; parents?: string[]; fullText?: string; raw?: string }): string {
	const clauses: string[] = ["trashed = false"];
	if (parts.raw) clauses.push(`(${parts.raw})`);
	if (parts.name) clauses.push(`name = '${parts.name.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}'`);
	if (parts.mimeType) clauses.push(`mimeType = '${parts.mimeType}'`);
	if (parts.fullText) clauses.push(`fullText contains '${parts.fullText.replace(/'/g, "\\'")}'`);
	for (const parent of parts.parents ?? []) {
		if (parent === "root") clauses.push("'root' in parents");
		else clauses.push(`'${extractFileId(parent) ?? parent}' in parents`);
	}
	return clauses.join(" and ");
}

export async function searchFiles(options: {
	email: string;
	query?: string;
	pageSize?: number;
	orderBy?: string;
	pageToken?: string;
	signal?: AbortSignal;
}): Promise<{ files: DriveFile[]; nextPageToken?: string }> {
	const params = new URLSearchParams({
		q: options.query ?? driveQuery({}),
		fields: "nextPageToken,files(id,name,mimeType,modifiedTime,owners(emailAddress,displayName),parents,webViewLink,size)",
		pageSize: String(Math.min(Math.max(options.pageSize ?? 25, 1), 100)),
		includeItemsFromAllDrives: "true",
		supportsAllDrives: "true",
	});
	if (options.orderBy) params.set("orderBy", options.orderBy);
	if (options.pageToken) params.set("pageToken", options.pageToken);
	return googleJson({ email: options.email, url: `${ENDPOINT.drive}/files?${params}`, signal: options.signal });
}

/**
 * Accepts an ID, a Google URL, or a name. Names are searched (optionally
 * narrowed by MIME type); an ambiguous name fails with the candidates listed
 * rather than silently editing the wrong file.
 */
export async function resolveFile(options: {
	email: string;
	ref: string;
	mimeType?: string;
	signal?: AbortSignal;
}): Promise<DriveFile> {
	if (!options.ref?.trim()) throw new Error("No file given. Pass an ID, a Google Docs/Sheets URL, or a file name.");
	const id = extractFileId(options.ref);
	if (id) {
		return googleJson<DriveFile>({
			email: options.email,
			url: `${ENDPOINT.drive}/files/${id}?fields=id,name,mimeType,modifiedTime,owners(emailAddress,displayName),parents,webViewLink,size&supportsAllDrives=true`,
			signal: options.signal,
		});
	}
	const query = driveQuery({ name: options.ref.trim(), mimeType: options.mimeType });
	const { files } = await searchFiles({ email: options.email, query, pageSize: 6, signal: options.signal });
	if (!files.length) {
		throw new Error(
			`No file named "${options.ref}"${options.mimeType ? ` with type ${options.mimeType}` : ""} is visible to this account. Use google_drive_search to look it up.`,
		);
	}
	if (files.length > 1) {
		const list = files
			.map((f) => `${f.id}  ${f.name}  (${f.mimeType}, modified ${f.modifiedTime ?? "?"})`)
			.join("\n");
		throw new Error(`"${options.ref}" matches ${files.length} files. Pass one of these IDs:\n${list}`);
	}
	return files[0]!;
}

/* ------------------------------------------------------------------ *
 * Docs helpers
 * ------------------------------------------------------------------ */

type DocsElement = {
	textRun?: { content?: string };
	startIndex?: number;
	endIndex?: number;
	paragraph?: { paragraphStyle?: { namedStyleType?: string; headingId?: string } };
	table?: { tableRows?: Array<{ tableCells?: Array<{ content?: DocsStructuralElement[] }> }> };
};

export type DocsStructuralElement = {
	paragraph?: { elements?: DocsElement[]; paragraphStyle?: { namedStyleType?: string } };
	table?: DocsElement["table"];
	startIndex?: number;
	endIndex?: number;
};

export type GoogleDoc = { title?: string; body?: { content?: DocsStructuralElement[] } };

function paragraphText(element: DocsStructuralElement): string {
	return (element.paragraph?.elements ?? []).map((part) => part.textRun?.content ?? "").join("");
}

export function docText(doc: GoogleDoc): string {
	const lines: string[] = [];
	const walk = (elements: DocsStructuralElement[] | undefined, depth: number) => {
		for (const element of elements ?? []) {
			if (element.paragraph === undefined && element.table === undefined) continue;
			if (element.table) {
				for (const row of element.table.tableRows ?? []) {
					const cells = (row.tableCells ?? []).map((cell) =>
						(cell.content ?? []).map(paragraphText).join("").trim(),
					);
					lines.push(`${"\t".repeat(depth)}| ${cells.join(" | ")} |`);
				}
				continue;
			}
			const text = paragraphText(element);
			if (text.trim() || lines.length) lines.push(text.replace(/\n$/, ""));
		}
	};
	walk(doc.body?.content, 0);
	return lines.join("\n").trimEnd();
}

/** Paragraph/heading map with the indexes the Docs API needs for edits. */
export function docOutline(doc: GoogleDoc): Array<{
	index: number;
	endIndex: number;
	style: string;
	text: string;
}> {
	const out: Array<{ index: number; endIndex: number; style: string; text: string }> = [];
	for (const element of doc.body?.content ?? []) {
		if (!element.paragraph) continue;
		out.push({
			index: element.startIndex ?? 0,
			endIndex: element.endIndex ?? 0,
			style: element.paragraph.paragraphStyle?.namedStyleType ?? "NORMAL_TEXT",
			text: paragraphText(element).replace(/\n$/, ""),
		});
	}
	return out.filter((entry) => entry.text.length > 0);
}

export function docEndIndex(doc: GoogleDoc): number {
	const content = doc.body?.content ?? [];
	const last = content[content.length - 1];
	return last?.endIndex ?? 1;
}

/* ------------------------------------------------------------------ *
 * Export / download
 * ------------------------------------------------------------------ */

const EXPORT_MIME: Record<string, Record<string, string>> = {
	[MIME.doc]: {
		md: "text/markdown",
		markdown: "text/markdown",
		txt: "text/plain",
		text: "text/plain",
		pdf: "application/pdf",
		docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
		html: "text/html",
		rtf: "application/rtf",
	},
	[MIME.sheet]: {
		csv: "text/csv",
		txt: "text/tab-separated-values",
		tsv: "text/tab-separated-values",
		xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
		pdf: "application/pdf",
		html: "application/zip",
	},
	[MIME.slides]: {
		txt: "text/plain",
		pdf: "application/pdf",
		pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
	},
};

export const DEFAULT_FORMAT: Record<string, string> = {
	[MIME.doc]: "md",
	[MIME.sheet]: "csv",
	[MIME.slides]: "txt",
};

export function exportMimeFor(mimeType: string, format?: string): string {
	const table = EXPORT_MIME[mimeType];
	if (!table) throw new Error(`${mimeType} is not a Google-native file; it can be downloaded directly (format ignored).`);
	const chosen = format ?? DEFAULT_FORMAT[mimeType]!;
	const mime = table[chosen];
	if (!mime) throw new Error(`Format "${chosen}" is not available for ${mimeType}. Try: ${Object.keys(table).join(", ")}`);
	return mime;
}

export function extensionFor(mimeType: string, format?: string): string {
	if (format) return format;
	const table: Record<string, string> = {
		"text/markdown": "md",
		"text/plain": "txt",
		"text/csv": "csv",
		"text/tab-separated-values": "tsv",
		"application/pdf": "pdf",
		"text/html": "html",
		"application/zip": "zip",
		"application/rtf": "rtf",
		"application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
		"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xlsx",
		"application/vnd.openxmlformats-officedocument.presentationml.presentation": "pptx",
	};
	return table[mimeType] ?? "bin";
}

export async function exportFile(options: {
	email: string;
	fileId: string;
	mimeType: string;
	format?: string;
	signal?: AbortSignal;
}): Promise<{ mimeType: string; bytes: ArrayBuffer }> {
	if (GOOGLE_NATIVE.has(options.mimeType)) {
		const mime = exportMimeFor(options.mimeType, options.format);
		const bytes = await googleBytes({
			email: options.email,
			url: `${ENDPOINT.drive}/files/${options.fileId}/export?mimeType=${encodeURIComponent(mime)}`,
			signal: options.signal,
		});
		return { mimeType: mime, bytes };
	}
	const bytes = await googleBytes({
		email: options.email,
		url: `${ENDPOINT.drive}/files/${options.fileId}?alt=media&supportsAllDrives=true`,
		signal: options.signal,
	});
	return { mimeType: options.mimeType, bytes };
}

export function writeLocalFile(path: string, bytes: ArrayBuffer): number {
	mkdirSync(dirname(path), { recursive: true });
	writeFileSync(path, Buffer.from(bytes));
	return bytes.byteLength;
}

/**
 * Resumable upload (create, or PATCH an existing file's bytes when `fileId` is
 * given). One PUT for the whole body keeps it simple and removes the 5 MB
 * multipart ceiling; the content type is what decides whether Drive stores a
 * real notebook type or an opaque blob.
 */
export async function resumableUpload(options: {
	email: string;
	bytes: Buffer;
	contentType: string;
	metadata: Record<string, unknown>;
	fileId?: string;
	signal?: AbortSignal;
}): Promise<{ id: string; name: string; mimeType?: string }> {
	const token = await accessToken(options.email, options.signal);
	const fields = "fields=id,name,mimeType,size,webViewLink";
	const base = options.fileId
		? `${ENDPOINT.upload}/files/${options.fileId}?uploadType=resumable&supportsAllDrives=true&${fields}`
		: `${ENDPOINT.upload}/files?uploadType=resumable&supportsAllDrives=true&${fields}`;

	const start = await fetch(base, {
		method: options.fileId ? "PATCH" : "POST",
		headers: {
			authorization: `Bearer ${token}`,
			"content-type": "application/json; charset=UTF-8",
			"x-upload-content-type": options.contentType,
			"x-upload-content-length": String(options.bytes.byteLength),
		},
		body: JSON.stringify(options.metadata),
		signal: options.signal,
	});
	if (!start.ok) throw new Error(`Upload could not start: ${start.status} ${await start.text()}`);
	const session = start.headers.get("location");
	if (!session) throw new Error("Upload session URI missing from Drive's response.");

	const upload = await fetch(session, {
		method: "PUT",
		headers: { "content-type": options.contentType, "content-length": String(options.bytes.byteLength) },
		body: options.bytes,
		signal: options.signal,
	});
	if (!upload.ok) throw new Error(`Upload failed: ${upload.status} ${await upload.text()}`);
	return (await upload.json()) as { id: string; name: string; mimeType?: string };
}

/* ------------------------------------------------------------------ *
 * Output shaping
 * ------------------------------------------------------------------ */

export const MODEL_TEXT_LIMIT = 18_000;

/**
 * Model-facing text over the limit is written to a temp file and replaced by a
 * short note naming it, so nothing is silently dropped.
 */
export function clampText(text: string, label = "output", limit = MODEL_TEXT_LIMIT): string {
	if (text.length <= limit) return text;
	const path = join(tmpdir(), `pi-google-${label.replace(/[^a-zA-Z0-9._-]+/g, "-")}-${Date.now()}.txt`);
	writeFileSync(path, text);
	const head = text.slice(0, Math.floor(limit * 0.6));
	const tail = text.slice(-Math.floor(limit * 0.2));
	return `${head}\n\n…${text.length - head.length - tail.length} chars omitted. Full ${label} saved to ${path}…\n\n${tail}`;
}
