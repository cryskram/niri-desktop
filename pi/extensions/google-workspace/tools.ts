/**
 * The Google tools: Sheets, Docs, and Drive on any connected account.
 *
 * Every tool takes an optional `account` (email) and defaults to the account
 * selected with `/google use`. Read-only tools are annotated as such so
 * permission layers can tell them apart.
 */
import { readFileSync, statSync } from "node:fs";
import { basename, extname, join } from "node:path";
import { Type } from "@earendil-works/pi-ai";
import { defineTool } from "@earendil-works/pi-coding-agent";
import {
	accessToken,
	clampText,
	docEndIndex,
	docOutline,
	docText,
	driveQuery,
	ENDPOINT,
	exportFile,
	extensionFor,
	extractFileId,
	GOOGLE_NATIVE,
	googleJson,
	MIME,
	resolveFile,
	searchFiles,
	requireAccount,
	writeLocalFile,
	type GoogleDoc,
} from "./api.ts";
import { loadAccounts } from "./store.ts";
import { scopeLabels } from "./oauth.ts";

const NAMESPACE = {
	name: "google",
	aliases: ["google-workspace", "gw"],
	description: "Google Workspace: Sheets, Docs, and Drive on any connected Google account.",
	instructions:
		"Pass `account` (an email) to target a specific connected Google account; omit it for the active one. " +
		"File arguments accept a raw ID, a docs.google.com/drive.google.com URL, or an exact file name (a name must be unambiguous). " +
		"Run `/google` in Pi to add accounts, switch the active one, or re-authenticate.",
};

const accountParam = Type.Optional(
	Type.String({ description: "Connected Google account email; defaults to the active account." }),
);

const READ_ONLY = { readOnlyHint: true, openWorldHint: true } as const;
const MUTATING = { readOnlyHint: false, destructiveHint: false, openWorldHint: true } as const;
const DESTRUCTIVE = { readOnlyHint: false, destructiveHint: true, openWorldHint: true } as const;

const MIME_SHORTHANDS: Record<string, string> = {
	doc: MIME.doc,
	docs: MIME.doc,
	document: MIME.doc,
	sheet: MIME.sheet,
	sheets: MIME.sheet,
	spreadsheet: MIME.sheet,
	slides: MIME.slides,
	presentation: MIME.slides,
	folder: MIME.folder,
	pdf: "application/pdf",
	docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
	xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
	pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
	csv: "text/csv",
	txt: "text/plain",
	image: "image/",
};

function expandMime(value: string | undefined): string | undefined {
	if (!value) return undefined;
	return MIME_SHORTHANDS[value.toLowerCase()] ?? value;
}

const UPLOAD_MIME: Record<string, string> = {
	".pdf": "application/pdf",
	".csv": "text/csv",
	".tsv": "text/tab-separated-values",
	".txt": "text/plain",
	".md": "text/markdown",
	".json": "application/json",
	".html": "text/html",
	".zip": "application/zip",
	".png": "image/png",
	".jpg": "image/jpeg",
	".jpeg": "image/jpeg",
	".gif": "image/gif",
	".svg": "image/svg+xml",
	".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
	".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
	".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
	".odt": "application/vnd.oasis.opendocument.text",
	".ods": "application/vnd.oasis.opendocument.spreadsheet",
	".mp4": "video/mp4",
};

function text(value: string, details: Record<string, unknown>) {
	return { content: [{ type: "text" as const, text: value }], details };
}

function sheetLink(id: string): string {
	return `https://docs.google.com/spreadsheets/d/${id}/edit`;
}

function docLink(id: string): string {
	return `https://docs.google.com/document/d/${id}/edit`;
}

function fileLink(id: string): string {
	return `https://drive.google.com/file/d/${id}/view`;
}

async function resolveSpreadsheet(ref: string, account?: string, signal?: AbortSignal) {
	const { email } = requireAccount(account);
	const file = await resolveFile({ email, ref, mimeType: MIME.sheet, signal });
	return { email, file };
}

async function resolveDocument(ref: string, account?: string, signal?: AbortSignal) {
	const { email } = requireAccount(account);
	const file = await resolveFile({ email, ref, mimeType: MIME.doc, signal });
	return { email, file };
}

/* ------------------------------------------------------------------ *
 * Accounts
 * ------------------------------------------------------------------ */

const googleAccounts = defineTool({
	name: "google_accounts",
	label: "Google accounts",
	description:
		"List the Google accounts connected to Pi: email, whether it is a personal or Workspace-managed account, " +
		"which one is active, granted scopes, and whether a token needs re-authentication. Accounts are added and " +
		"switched with the /google command, not from a tool.",
	parameters: Type.Object({}),
	namespace: NAMESPACE,
	annotations: READ_ONLY,
	promptSnippet: "List connected Google accounts and which one is active",
	async execute() {
		const store = loadAccounts();
		const emails = Object.keys(store.accounts).sort();
		if (!emails.length) {
			return text("No Google account is connected. Run /google in Pi to add one.", { accounts: [] });
		}
		const lines = emails.map((email) => {
			const record = store.accounts[email]!;
			const kind = record.hostedDomain ? `workspace (${record.hostedDomain})` : "personal";
			const state = record.needsReauth
				? "needs re-auth (/google)"
				: record.expiresAt && record.expiresAt > Date.now()
					? `token valid until ${new Date(record.expiresAt).toISOString()}`
					: "refreshable";
			const active = email === store.active ? " (active)" : "";
			return `• ${email}${active} — ${kind}; ${state}; scopes: ${scopeLabels(record.scopes) || "unknown"}`;
		});
		return text(lines.join("\n"), { active: store.active, accounts: emails });
	},
});

/* ------------------------------------------------------------------ *
 * Sheets
 * ------------------------------------------------------------------ */

const sheetsRead = defineTool({
	name: "google_sheets_read",
	label: "Read spreadsheet",
	description:
		"Read a Google Sheet: spreadsheet metadata (title, tabs, grid sizes) always, plus cell values for any ranges given " +
		"in A1 notation ('Sheet1!A1:D20', 'Sheet1'). Returns formatted values, so dates and currency come back as displayed.",
	parameters: Type.Object({
		spreadsheet: Type.String({ description: "Spreadsheet ID, URL, or exact file name." }),
		ranges: Type.Optional(
			Type.Array(Type.String({ description: "A1 range, e.g. 'Sheet1!A1:D20' or 'Sheet1'." }), {
				description: "Ranges to read. Omit for metadata only.",
			}),
		),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: READ_ONLY,
	promptSnippet: "Read Google Sheet values and structure",
	promptGuidelines: [
		"Use A1 notation for ranges; a bare sheet name reads the used range of that tab.",
		"Prefer one read with several ranges over repeated single-range reads.",
	],
	async execute(_id, params, signal) {
		const { email, file } = await resolveSpreadsheet(params.spreadsheet, params.account, signal);
		const meta = await googleJson<{
			properties?: { title?: string };
			sheets?: Array<{ properties?: { sheetId?: number; title?: string; index?: number; hidden?: boolean; gridProperties?: Record<string, number> } }>;
		}>({
			email,
			url: `${ENDPOINT.sheets}/${file.id}?fields=spreadsheetId,properties.title,sheets(properties(sheetId,title,index,hidden,gridProperties))`,
			signal,
		});
		const tabs = (meta.sheets ?? []).map((sheet) => ({
			title: sheet.properties?.title,
			sheetId: sheet.properties?.sheetId,
			hidden: sheet.properties?.hidden ?? false,
			grid: sheet.properties?.gridProperties,
		}));
		const values: Record<string, unknown> = {};
		for (const range of params.ranges ?? []) {
			const result = await googleJson({
				email,
				url: `${ENDPOINT.sheets}/${file.id}/values/${encodeURIComponent(range)}?valueRenderOption=FORMATTED_VALUE`,
				signal,
			});
			values[range] = result;
		}
		const payload = {
			spreadsheetId: file.id,
			title: meta.properties?.title ?? file.name,
			url: sheetLink(file.id),
			tabs,
			...(params.ranges?.length ? { ranges: values } : {}),
		};
		return text(clampText(JSON.stringify(payload, null, 2), "sheet-read"), { account: email, spreadsheetId: file.id });
	},
});

const sheetsWrite = defineTool({
	name: "google_sheets_write",
	label: "Write spreadsheet values",
	description:
		"Write values or formulas into one or more ranges of a Google Sheet in a single batch. " +
		"Values are 2D arrays (rows of cells). USER_ENTERED parses input like the UI does (formulas, dates, numbers); RAW stores strings verbatim.",
	parameters: Type.Object({
		spreadsheet: Type.String({ description: "Spreadsheet ID, URL, or exact file name." }),
		data: Type.Array(
			Type.Object({
				range: Type.String({ description: "A1 range to write, e.g. 'Sheet1!B2:D4'." }),
				values: Type.Array(Type.Array(Type.Union([Type.String(), Type.Number(), Type.Boolean(), Type.Null()])), {
					description: "Row-major cell values.",
				}),
			}),
			{ description: "One entry per range; all are written atomically." },
		),
		value_input_option: Type.Optional(Type.Union([Type.Literal("RAW"), Type.Literal("USER_ENTERED")], {
			description: "Default USER_ENTERED.",
		})),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: MUTATING,
	promptSnippet: "Write Google Sheet values or formulas",
	promptGuidelines: [
		"To append rows below existing data, read the sheet first and write to the next free row, or use google_api with values:append.",
		"Set value_input_option RAW when the exact string (leading zeros, no formula parsing) matters.",
	],
	async execute(_id, params, signal) {
		const { email, file } = await resolveSpreadsheet(params.spreadsheet, params.account, signal);
		const result = await googleJson<{ totalUpdatedCells?: number; responses?: unknown[] }>({
			email,
			method: "POST",
			url: `${ENDPOINT.sheets}/${file.id}/values:batchUpdate`,
			body: {
				valueInputOption: params.value_input_option ?? "USER_ENTERED",
				data: params.data.map((entry) => ({ range: entry.range, values: entry.values })),
			},
			signal,
		});
		const ranges = params.data.map((entry) => entry.range).join(", ");
		return text(
			`Updated ${result.totalUpdatedCells ?? "?"} cells in ${file.name} (${ranges}).\n${sheetLink(file.id)}`,
			{ account: email, spreadsheetId: file.id, updatedCells: result.totalUpdatedCells ?? null },
		);
	},
});

const sheetsBatch = defineTool({
	name: "google_sheets_batch",
	label: "Sheet structural update",
	description:
		"Run raw spreadsheets.batchUpdate requests: add or delete sheets, formatting, merges, conditional formatting, " +
		"filters, named ranges, row/column inserts. Pass the request objects exactly as the Sheets API defines them.",
	parameters: Type.Object({
		spreadsheet: Type.String({ description: "Spreadsheet ID, URL, or exact file name." }),
		requests: Type.Array(Type.Any(), {
			description:
				"spreadsheets.batchUpdate requests, e.g. [{\"repeatCell\":{\"range\":{\"sheetId\":0,\"startRowIndex\":0,\"endRowIndex\":1},\"cell\":{\"userEnteredFormat\":{\"textFormat\":{\"bold\":true}}},\"fields\":\"userEnteredFormat.textFormat.bold\"}}]",
		}),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: MUTATING,
	promptSnippet: "Structural Google Sheets edits (formatting, tabs, merges)",
	async execute(_id, params, signal) {
		const { email, file } = await resolveSpreadsheet(params.spreadsheet, params.account, signal);
		const result = await googleJson<{ replies?: unknown[] }>({
			email,
			method: "POST",
			url: `${ENDPOINT.sheets}/${file.id}:batchUpdate`,
			body: { requests: params.requests },
			signal,
		});
		return text(
			`Applied ${params.requests.length} request(s) to ${file.name}. Replies:\n${clampText(JSON.stringify(result.replies ?? [], null, 2), "sheet-batch")}\n${sheetLink(file.id)}`,
			{ account: email, spreadsheetId: file.id, requests: params.requests.length },
		);
	},
});

const sheetsCreate = defineTool({
	name: "google_sheets_create",
	label: "Create spreadsheet",
	description: "Create a new Google Spreadsheet, optionally with named tabs, and return its ID and URL.",
	parameters: Type.Object({
		title: Type.String({ description: "Spreadsheet title." }),
		tabs: Type.Optional(Type.Array(Type.String({ description: "Tab name." }), { description: "Tab names to create." })),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: MUTATING,
	promptSnippet: "Create a Google Spreadsheet",
	async execute(_id, params, signal) {
		const { email } = requireAccount(params.account);
		const body: Record<string, unknown> = { properties: { title: params.title } };
		if (params.tabs?.length) body.sheets = params.tabs.map((title) => ({ properties: { title } }));
		const created = await googleJson<{ spreadsheetId: string; properties?: { title?: string } }>({
			email,
			method: "POST",
			url: ENDPOINT.sheets,
			body,
			signal,
		});
		return text(`Created "${created.properties?.title ?? params.title}".\n${sheetLink(created.spreadsheetId)}`, {
			account: email,
			spreadsheetId: created.spreadsheetId,
		});
	},
});

/* ------------------------------------------------------------------ *
 * Docs
 * ------------------------------------------------------------------ */

const docsRead = defineTool({
	name: "google_docs_read",
	label: "Read document",
	description:
		"Read a Google Doc as plain text (headings, lists and tables flattened in document order). " +
		"With include_structure, also returns each paragraph's start/end index and style — the indexes batchUpdate needs for editing.",
	parameters: Type.Object({
		document: Type.String({ description: "Document ID, URL, or exact file name." }),
		include_structure: Type.Optional(Type.Boolean({ description: "Include paragraph indexes and heading styles. Default false." })),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: READ_ONLY,
	promptSnippet: "Read a Google Doc as text, optionally with indexes",
	async execute(_id, params, signal) {
		const { email, file } = await resolveDocument(params.document, params.account, signal);
		const doc = await googleJson<GoogleDoc>({
			email,
			url: `${ENDPOINT.docs}/${file.id}`,
			signal,
		});
		const parts = [clampText(docText(doc), "doc-text")];
		if (params.include_structure) {
			const outline = docOutline(doc)
				.map((entry) => `[${entry.index}-${entry.endIndex}] ${entry.style}: ${entry.text.slice(0, 120)}`)
				.join("\n");
			parts.push(`\n--- structure (start-end style: text) ---\n${clampText(outline, "doc-outline")}`);
		}
		parts.push(`\n${docLink(file.id)}`);
		return text(parts.join("\n"), { account: email, documentId: file.id });
	},
});

const docsWrite = defineTool({
	name: "google_docs_write",
	label: "Edit document",
	description:
		"Edit a Google Doc. Either pass raw documents.batchUpdate requests (full power: formatting ranges, tables, " +
		"replaceAllText, style updates) or use the convenience form: text plus mode append/replace.",
	parameters: Type.Object({
		document: Type.String({ description: "Document ID, URL, or exact file name." }),
		requests: Type.Optional(
			Type.Array(Type.Any(), {
				description:
					"documents.batchUpdate requests, e.g. [{\"replaceAllText\":{\"containsText\":{\"text\":\"{{name}}\"},\"replaceText\":\"Ada\"}}]",
			}),
		),
		text: Type.Optional(Type.String({ description: "Text to append or to replace the body with." })),
		mode: Type.Optional(Type.Union([Type.Literal("append"), Type.Literal("replace")], { description: "Default append." })),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: MUTATING,
	promptSnippet: "Edit a Google Doc (append, replace, or raw batchUpdate)",
	promptGuidelines: [
		"Indexes are 1-based UTF-16 offsets; read the doc with include_structure before targeting a specific paragraph.",
		"Formatting is applied to index ranges, so insert text first, then format the range it produced.",
	],
	async execute(_id, params, signal) {
		const { email, file } = await resolveDocument(params.document, params.account, signal);
		const requests: unknown[] = [...(params.requests ?? [])];
		if (params.text !== undefined) {
			const doc = await googleJson<GoogleDoc>({
				email,
				url: `${ENDPOINT.docs}/${file.id}`,
				signal,
			});
			const endIndex = docEndIndex(doc);
			const empty = endIndex <= 2;
			if ((params.mode ?? "append") === "replace") {
				if (!empty) requests.push({ deleteContentRange: { range: { startIndex: 1, endIndex: endIndex - 1 } } });
				requests.push({ insertText: { location: { index: 1 }, text: params.text } });
			} else {
				const existing = docText(doc);
				const separator = existing && !existing.endsWith("\n") ? "\n" : "";
				requests.push({ insertText: { location: { index: Math.max(1, endIndex - 1) }, text: `${separator}${params.text}` } });
			}
		}
		if (!requests.length) throw new Error("Nothing to do: pass `requests`, or `text` with mode append/replace.");
		const result = await googleJson<{ replies?: unknown[] }>({
			email,
			method: "POST",
			url: `${ENDPOINT.docs}/${file.id}:batchUpdate`,
			body: { requests },
			signal,
		});
		return text(`Applied ${requests.length} request(s) to ${file.name}.\n${docLink(file.id)}`, {
			account: email,
			documentId: file.id,
			requests: requests.length,
			replies: result.replies?.length ?? 0,
		});
	},
});

const docsCreate = defineTool({
	name: "google_docs_create",
	label: "Create document",
	description: "Create a Google Doc with a title and optional initial body text, and return its ID and URL.",
	parameters: Type.Object({
		title: Type.String({ description: "Document title." }),
		text: Type.Optional(Type.String({ description: "Initial body text." })),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: MUTATING,
	promptSnippet: "Create a Google Doc",
	async execute(_id, params, signal) {
		const { email } = requireAccount(params.account);
		const created = await googleJson<{ documentId: string; title?: string }>({
			email,
			method: "POST",
			url: ENDPOINT.docs,
			body: { title: params.title },
			signal,
		});
		if (params.text) {
			await googleJson({
				email,
				method: "POST",
				url: `${ENDPOINT.docs}/${created.documentId}:batchUpdate`,
				body: { requests: [{ insertText: { location: { index: 1 }, text: params.text } }] },
				signal,
			});
		}
		return text(`Created "${created.title ?? params.title}"${params.text ? " with body text" : ""}.\n${docLink(created.documentId)}`, {
			account: email,
			documentId: created.documentId,
		});
	},
});

/* ------------------------------------------------------------------ *
 * Drive
 * ------------------------------------------------------------------ */

const driveSearch = defineTool({
	name: "google_drive_search",
	label: "Search Drive",
	description:
		"Search Google Drive. Combine name, mime_type, parent and full_text filters, or pass a raw Drive query. " +
		"Returns id, name, type, owners, modified time and a link for each hit.",
	parameters: Type.Object({
		query: Type.Optional(Type.String({ description: "Raw Drive query, ANDed with the other filters." })),
		name: Type.Optional(Type.String({ description: "Exact file name." })),
		mime_type: Type.Optional(Type.String({ description: "MIME type or shorthand: doc, sheet, slides, folder, pdf, docx, xlsx, pptx, csv." })),
		parent: Type.Optional(Type.String({ description: "Folder ID, 'root', or an exact folder name." })),
		full_text: Type.Optional(Type.String({ description: "Full-text content search." })),
		page_size: Type.Optional(Type.Number({ description: "Max results (default 25)." })),
		order_by: Type.Optional(Type.String({ description: "e.g. 'modifiedTime desc' or 'name'." })),
		page_token: Type.Optional(Type.String({ description: "Continuation token from a previous call." })),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: READ_ONLY,
	promptSnippet: "Search Google Drive for files and folders",
	promptGuidelines: [
		"Drive query syntax is limited: name, fullText, mimeType, parents and modifiedTime are reliable; there are no wildcards in `name`.",
		"Page through results with page_token rather than raising page_size past 100.",
	],
	async execute(_id, params, signal) {
		const { email } = requireAccount(params.account);
		let parent: string[] | undefined;
		if (params.parent) {
			const id = extractFileId(params.parent);
			if (id || params.parent === "root") parent = [id ?? params.parent];
			else {
				const folder = await resolveFile({ email, ref: params.parent, mimeType: MIME.folder, signal });
				parent = [folder.id];
			}
		}
		const query = driveQuery({
			name: params.name,
			mimeType: expandMime(params.mime_type),
			parents: parent,
			fullText: params.full_text,
			raw: params.query,
		});
		const result = await searchFiles({
			email,
			query,
			pageSize: params.page_size,
			orderBy: params.order_by,
			pageToken: params.page_token,
			signal,
		});
		const files = result.files ?? [];
		if (!files.length) {
			return text(`No files match: ${query}`, { account: email, query, count: 0 });
		}
		const lines = files.map((file) => {
			const owner = file.owners?.[0]?.emailAddress ?? "unknown owner";
			return `• ${file.name} — ${file.mimeType}\n  id: ${file.id}\n  modified: ${file.modifiedTime ?? "?"} · owner: ${owner}\n  ${file.webViewLink ?? ""}`;
		});
		const more = result.nextPageToken ? `\n\nMore results: page_token=${result.nextPageToken}` : "";
		return text(`${files.length} file(s) for: ${query}\n\n${lines.join("\n")}${more}`, {
			account: email,
			query,
			count: files.length,
			nextPageToken: result.nextPageToken ?? null,
		});
	},
});

const driveRead = defineTool({
	name: "google_drive_read",
	label: "Read Drive file",
	description:
		"Read any Drive file by ID, URL or name. Google Docs come back as Markdown, Slides as text, Sheets as tabs plus any " +
		"requested ranges; other files return metadata and a link (use google_drive_export to get the bytes).",
	parameters: Type.Object({
		file: Type.String({ description: "File ID, Google URL, or exact file name." }),
		ranges: Type.Optional(Type.Array(Type.String({ description: "A1 ranges, for spreadsheets." }))),
		include_content: Type.Optional(Type.Boolean({ description: "Include document content. Default true." })),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: READ_ONLY,
	promptSnippet: "Read a Google Doc, Sheet, or Drive file by id/name/URL",
	async execute(_id, params, signal) {
		const { email } = requireAccount(params.account);
		const file = await resolveFile({ email, ref: params.file, signal });
		const header = [
			`${file.name} (${file.mimeType})`,
			`id: ${file.id}`,
			`modified: ${file.modifiedTime ?? "?"}${file.size ? ` · ${file.size} bytes` : ""}`,
			`owner: ${file.owners?.[0]?.emailAddress ?? "?"}`,
			file.webViewLink ?? fileLink(file.id),
		].join("\n");
		if (params.include_content === false || !GOOGLE_NATIVE.has(file.mimeType)) {
			return text(header, { account: email, fileId: file.id, mimeType: file.mimeType });
		}
		if (file.mimeType === MIME.sheet) {
			const meta = await googleJson<{
				properties?: { title?: string };
				sheets?: Array<{ properties?: { title?: string; sheetId?: number; gridProperties?: Record<string, number> } }>;
			}>({
				email,
				url: `${ENDPOINT.sheets}/${file.id}?fields=properties.title,sheets(properties(sheetId,title,gridProperties))`,
				signal,
			});
			const tabs = (meta.sheets ?? []).map((sheet) => sheet.properties?.title).filter(Boolean);
			const values: Record<string, unknown> = {};
			for (const range of params.ranges ?? []) {
				values[range] = await googleJson({
					email,
					url: `${ENDPOINT.sheets}/${file.id}/values/${encodeURIComponent(range)}?valueRenderOption=FORMATTED_VALUE`,
					signal,
				});
			}
			const body = { tabs, ...(params.ranges?.length ? { ranges: values } : {}) };
			return text(`${header}\ntabs: ${tabs.join(", ") || "none"}\n\n${clampText(JSON.stringify(body, null, 2), "drive-sheet")}`, {
				account: email,
				fileId: file.id,
				mimeType: file.mimeType,
			});
		}
		const format = file.mimeType === MIME.doc ? "md" : "txt";
		const { bytes, mimeType } = await exportFile({ email, fileId: file.id, mimeType: file.mimeType, format, signal });
		const content = Buffer.from(bytes).toString("utf8");
		return text(`${header}\nexported as ${mimeType}\n\n${clampText(content, "drive-read")}`, {
			account: email,
			fileId: file.id,
			mimeType: file.mimeType,
		});
	},
});

const driveExport = defineTool({
	name: "google_drive_export",
	label: "Export Drive file",
	description:
		"Export a Google Doc, Sheet or Slides deck (or download a binary file) to a local path. " +
		"Formats: docs md/txt/pdf/docx/html/rtf, sheets csv/tsv/xlsx/pdf, slides txt/pdf/pptx. " +
		"A csv export covers only the first tab — read specific ranges with google_sheets_read instead.",
	parameters: Type.Object({
		file: Type.String({ description: "File ID, Google URL, or exact file name." }),
		to: Type.String({ description: "Local destination path (a directory keeps the file's name), e.g. ~/Downloads/report.md" }),
		format: Type.Optional(Type.String({ description: "Export format; defaults to md for docs, csv for sheets, txt for slides." })),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: READ_ONLY,
	promptSnippet: "Export a Google file to a local path",
	async execute(_id, params, signal) {
		const { email } = requireAccount(params.account);
		const file = await resolveFile({ email, ref: params.file, signal });
		const { bytes, mimeType } = await exportFile({
			email,
			fileId: file.id,
			mimeType: file.mimeType,
			format: params.format,
			signal,
		});
		const extension = extensionFor(mimeType, params.format);
		const target =
			params.to.endsWith("/") || statSync(params.to, { throwIfNoEntry: false })?.isDirectory()
				? join(params.to, `${file.name}.${extension}`.replace(/[/\\]/g, "-"))
				: params.to;
		const written = writeLocalFile(target, bytes);
		return text(`Exported ${file.name} → ${target} (${written} bytes, ${mimeType}).`, {
			account: email,
			fileId: file.id,
			path: target,
			bytes: written,
		});
	},
});

const driveWrite = defineTool({
	name: "google_drive_write",
	label: "Modify Drive",
	description:
		"Create and modify Drive items: create_folder, rename, move, copy, share, upload, trash, untrash, delete. " +
		"delete is permanent; trash is recoverable. share defaults to not emailing the grantee.",
	parameters: Type.Object({
		action: Type.Union(
			[
				Type.Literal("create_folder"),
				Type.Literal("rename"),
				Type.Literal("move"),
				Type.Literal("copy"),
				Type.Literal("share"),
				Type.Literal("upload"),
				Type.Literal("trash"),
				Type.Literal("untrash"),
				Type.Literal("delete"),
			],
			{ description: "Operation to perform." },
		),
		file: Type.Optional(Type.String({ description: "Target file: ID, URL, or exact name (not needed for create_folder/upload)." })),
		name: Type.Optional(Type.String({ description: "Name for create_folder, rename, copy or upload." })),
		parent: Type.Optional(Type.String({ description: "Folder for create_folder/upload (ID, name, or 'root')." })),
		to_parent: Type.Optional(Type.String({ description: "Destination folder for move/copy." })),
		role: Type.Optional(Type.Union([Type.Literal("reader"), Type.Literal("commenter"), Type.Literal("writer")], { description: "Role for share." })),
		grantee_type: Type.Optional(
			Type.Union([Type.Literal("user"), Type.Literal("group"), Type.Literal("domain"), Type.Literal("anyone")], {
				description: "Permission type for share. Default user.",
			}),
		),
		email_address: Type.Optional(Type.String({ description: "Grantee email for share." })),
		domain: Type.Optional(Type.String({ description: "Domain for grantee_type=domain." })),
		notify: Type.Optional(Type.Boolean({ description: "Email the grantee when sharing. Default false." })),
		local_path: Type.Optional(Type.String({ description: "Local file to upload." })),
		convert_to: Type.Optional(
			Type.String({ description: "Convert an upload to a Google type: doc, sheet, or slides." }),
		),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: DESTRUCTIVE,
	promptSnippet: "Create folders, rename/move/share/upload/trash Drive items",
	promptGuidelines: [
		"Prefer trash over delete; delete cannot be undone.",
		"Sharing grants real access to real people — confirm the grantee address before calling share.",
	],
	async execute(_id, params, signal) {
		const { email } = requireAccount(params.account);
		const folderId = async (ref: string | undefined): Promise<string | undefined> => {
			if (!ref) return undefined;
			const id = extractFileId(ref);
			if (id || ref === "root") return id ?? ref;
			const folder = await resolveFile({ email, ref, mimeType: MIME.folder, signal });
			return folder.id;
		};

		switch (params.action) {
			case "create_folder": {
				if (!params.name) throw new Error("create_folder needs a name.");
				const created = await googleJson<{ id: string; name: string }>({
					email,
					method: "POST",
					url: `${ENDPOINT.drive}/files?fields=id,name,webViewLink&supportsAllDrives=true`,
					body: { name: params.name, mimeType: MIME.folder, ...(params.parent ? { parents: [await folderId(params.parent)] } : {}) },
					signal,
				});
				return text(`Created folder "${created.name}" (${created.id}).`, { account: email, folderId: created.id });
			}
			case "rename": {
				const file = await resolveFile({ email, ref: params.file ?? "", signal });
				if (!params.name) throw new Error("rename needs a name.");
				await googleJson({
					email,
					method: "PATCH",
					url: `${ENDPOINT.drive}/files/${file.id}?fields=id,name&supportsAllDrives=true`,
					body: { name: params.name },
					signal,
				});
				return text(`Renamed "${file.name}" → "${params.name}".`, { account: email, fileId: file.id, name: params.name });
			}
			case "move": {
				const file = await resolveFile({ email, ref: params.file ?? "", signal });
				const destination = await folderId(params.to_parent);
				if (!destination) throw new Error("move needs to_parent.");
				const current = await googleJson<{ parents?: string[] }>({
					email,
					url: `${ENDPOINT.drive}/files/${file.id}?fields=parents&supportsAllDrives=true`,
					signal,
				});
				const remove = (current.parents ?? []).join(",");
				await googleJson({
					email,
					method: "PATCH",
					url: `${ENDPOINT.drive}/files/${file.id}?addParents=${encodeURIComponent(destination)}${remove ? `&removeParents=${encodeURIComponent(remove)}` : ""}&fields=id,parents&supportsAllDrives=true`,
					body: {},
					signal,
				});
				return text(`Moved "${file.name}" into ${destination}.`, { account: email, fileId: file.id, parent: destination });
			}
			case "copy": {
				const file = await resolveFile({ email, ref: params.file ?? "", signal });
				const copied = await googleJson<{ id: string; name: string }>({
					email,
					method: "POST",
					url: `${ENDPOINT.drive}/files/${file.id}/copy?fields=id,name,webViewLink&supportsAllDrives=true`,
					body: {
						...(params.name ? { name: params.name } : {}),
						...(params.to_parent ? { parents: [await folderId(params.to_parent)] } : {}),
					},
					signal,
				});
				return text(`Copied to "${copied.name}" (${copied.id}).`, { account: email, fileId: copied.id });
			}
			case "share": {
				const file = await resolveFile({ email, ref: params.file ?? "", signal });
				const type = params.grantee_type ?? "user";
				if (type === "user" && !params.email_address) throw new Error("share with type user needs email_address.");
				if (type === "domain" && !params.domain) throw new Error("share with type domain needs domain.");
				const permission = await googleJson<{ id: string }>({
					email,
					method: "POST",
					url: `${ENDPOINT.drive}/files/${file.id}/permissions?sendNotificationEmail=${params.notify === true}&supportsAllDrives=true&fields=id`,
					body: {
						role: params.role ?? "writer",
						type,
						...(params.email_address ? { emailAddress: params.email_address } : {}),
						...(params.domain ? { domain: params.domain } : {}),
					},
					signal,
				});
				const who = params.email_address ?? params.domain ?? "anyone";
				return text(`Shared "${file.name}" with ${who} as ${params.role ?? "writer"}.`, {
					account: email,
					fileId: file.id,
					permissionId: permission.id,
				});
			}
			case "upload": {
				if (!params.local_path) throw new Error("upload needs local_path.");
				const size = statSync(params.local_path).size;
				if (size > 200 * 1024 * 1024) throw new Error(`${params.local_path} is ${size} bytes; this tool caps uploads at 200 MB.`);
				const targetMime = params.convert_to
					? { doc: MIME.doc, sheet: MIME.sheet, slides: MIME.slides }[params.convert_to]
					: undefined;
				const contentType = targetMime ?? UPLOAD_MIME[extname(params.local_path).toLowerCase()] ?? "application/octet-stream";
				const metadata: Record<string, unknown> = { name: params.name ?? basename(params.local_path) };
				const parent = await folderId(params.parent);
				if (parent) metadata.parents = [parent];
				if (targetMime) metadata.mimeType = targetMime;
				const token = await accessToken(email, signal);
				const start = await fetch(`${ENDPOINT.upload}/files?uploadType=resumable&supportsAllDrives=true&fields=id,name,webViewLink`, {
					method: "POST",
					headers: {
						authorization: `Bearer ${token}`,
						"content-type": "application/json; charset=UTF-8",
						"x-upload-content-type": contentType,
						"x-upload-content-length": String(size),
					},
					body: JSON.stringify(metadata),
					signal,
				});
				if (!start.ok) throw new Error(`Upload could not start: ${start.status} ${await start.text()}`);
				const session = start.headers.get("location");
				if (!session) throw new Error("Upload session URI missing from Drive's response.");
				const upload = await fetch(session, {
					method: "PUT",
					headers: { "content-type": contentType, "content-length": String(size) },
					body: readFileSync(params.local_path),
					signal,
				});
				if (!upload.ok) throw new Error(`Upload failed: ${upload.status} ${await upload.text()}`);
				const uploaded = (await upload.json()) as { id: string; name: string };
				return text(`Uploaded ${params.local_path} → "${uploaded.name}" (${uploaded.id}).`, {
					account: email,
					fileId: uploaded.id,
				});
			}
			case "trash":
			case "untrash": {
				const file = await resolveFile({ email, ref: params.file ?? "", signal });
				await googleJson({
					email,
					method: "PATCH",
					url: `${ENDPOINT.drive}/files/${file.id}?fields=id,trashed&supportsAllDrives=true`,
					body: { trashed: params.action === "trash" },
					signal,
				});
				return text(`${params.action === "trash" ? "Trashed" : "Restored"} "${file.name}".`, {
					account: email,
					fileId: file.id,
				});
			}
			case "delete": {
				const file = await resolveFile({ email, ref: params.file ?? "", signal });
				await googleJson({
					email,
					method: "DELETE",
					url: `${ENDPOINT.drive}/files/${file.id}?supportsAllDrives=true`,
					signal,
				});
				return text(`Permanently deleted "${file.name}" (${file.id}).`, { account: email, fileId: file.id });
			}
			default:
				throw new Error(`Unsupported action ${params.action as string}`);
		}
	},
});

/* ------------------------------------------------------------------ *
 * Escape hatch
 * ------------------------------------------------------------------ */

const ALLOWED_HOSTS = new Set([
	"sheets.googleapis.com",
	"docs.googleapis.com",
	"gmail.googleapis.com",
	"tasks.googleapis.com",
	"www.googleapis.com",
]);

const ALLOWED_PATHS = [
	/^\/drive\//,
	/^\/upload\/drive\//,
	/^\/gmail\//,
	/^\/calendar\//,
	/^\/tasks\//,
	/^\/oauth2\//,
];

const googleApi = defineTool({
	name: "google_api",
	label: "Google API request",
	description:
		"Call a Google API directly when no dedicated tool fits (Gmail, Calendar, Tasks, Sheets values:append, Drive " +
		"permissions.list, …). The URL must point at a Google API host; the request runs with the selected account's token.",
	parameters: Type.Object({
		method: Type.Union([
			Type.Literal("GET"),
			Type.Literal("POST"),
			Type.Literal("PATCH"),
			Type.Literal("PUT"),
			Type.Literal("DELETE"),
		]),
		url: Type.String({
			description: "Full URL, e.g. https://gmail.googleapis.com/gmail/v1/users/me/messages?q=is%3Aunread — or https://sheets.googleapis.com/v4/spreadsheets/ID/values/Sheet1!A1:append",
		}),
		body: Type.Optional(Type.Any({ description: "JSON request body." })),
		account: accountParam,
	}),
	namespace: NAMESPACE,
	annotations: DESTRUCTIVE,
	promptSnippet: "Raw Google API call (Gmail, Calendar, Tasks, anything not covered)",
	promptGuidelines: [
		"Prefer the dedicated Sheets/Docs/Drive tools; use this for Gmail, Calendar, Tasks, or API details those tools do not expose.",
		"The account must have been granted the scope the endpoint needs — check google_accounts.",
	],
	async execute(_id, params, signal) {
		const { email } = requireAccount(params.account);
		let url: URL;
		try {
			url = new URL(params.url);
		} catch {
			throw new Error("Pass an absolute URL, e.g. https://gmail.googleapis.com/gmail/v1/users/me/profile");
		}
		if (url.protocol !== "https:") throw new Error("Only https:// URLs are allowed.");
		if (!ALLOWED_HOSTS.has(url.hostname)) {
			throw new Error(`Host ${url.hostname} is not allowed. Allowed: ${[...ALLOWED_HOSTS].join(", ")}`);
		}
		if (
			url.hostname === "www.googleapis.com" &&
			!ALLOWED_PATHS.some((pattern) => pattern.test(url.pathname))
		) {
			throw new Error(`Path ${url.pathname} is not allowed on www.googleapis.com (drive, upload/drive, gmail, calendar, tasks, oauth2 only).`);
		}
		const result = await googleJson({
			email,
			method: params.method,
			url: url.toString(),
			body: params.body,
			signal,
		});
		return text(clampText(JSON.stringify(result, null, 2), "google-api"), {
			account: email,
			method: params.method,
			url: `${url.origin}${url.pathname}`,
		});
	},
});

export const googleTools = [
	googleAccounts,
	sheetsRead,
	sheetsWrite,
	sheetsBatch,
	sheetsCreate,
	docsRead,
	docsWrite,
	docsCreate,
	driveSearch,
	driveRead,
	driveExport,
	driveWrite,
	googleApi,
];
