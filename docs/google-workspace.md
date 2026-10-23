# Google Workspace in Pi

`/google` connects Google accounts the way `/login` picks a provider, and 13 tools
work on Sheets, Docs and Drive using the selected account's own OAuth token.

Loaded from `pi/extensions/google-workspace/` via `modules/core.nix`; tool calls
are gated by the `google_*` rules in `settings.guard` there.

## One-time setup

### 1. An OAuth client (about five minutes, in the browser)

1. [console.cloud.google.com](https://console.cloud.google.com) → create a project (any name).
2. **APIs & Services → Library**: enable **Google Drive API**, **Google Sheets API**, **Google Docs API**.
   (`gcloud services enable drive.googleapis.com sheets.googleapis.com docs.googleapis.com --project=PROJECT_ID`)
3. **Google Auth Platform → Branding**: configure the consent screen if prompted. For a personal
   account the audience has to be **External**; add your own addresses under **Audience → Test users**.
4. **Google Auth Platform → Clients → Create client**, application type **Desktop app**. Download the JSON.
5. Optionally **Audience → Publish app**. Keep it in Testing and Google expires refresh tokens
   **every 7 days**; publishing keeps them alive at the cost of an "unverified app" warning at sign-in.
   The app stays unverified — that is fine for personal use, and it can be reverted.

### 2. Hand the client to Pi

```
/google setup            # paste the downloaded JSON, its path, or just the client ID
/google add              # Google's account chooser opens; pick or sign into an account
/google add --scopes=drive,sheets,docs,gmail,calendar
```

Repeat `/google add` for each account — a personal `@gmail.com` and a Workspace-managed
account coexist. `HD` in the record is Google's `hd` claim, which is what classifies an
account as Workspace-managed.

## Daily use

| Command | What it does |
|---|---|
| `/google` | Account menu: add, re-authenticate, make active, remove, doctor, client setup |
| `/google use <email\|number>` | Switch the active account (`1`/`2` follow `/google status` order) |
| `/google status` | Connected accounts, active one, token state, client in use |
| `/google rm <email\|number>` | Sign an account out of Pi |
| `/google doctor` | Verify every token against Google and report the granted scopes |
| `/google scopes` | Scope groups and the URLs they map to |

The footer status key `google` shows the active account (`● email (workspace)`).
zentui places it like any other extension status.

Every tool takes an optional `account` (email). Omitting it uses the active account, so
"read that sheet as my work account" is a per-call decision, not a session-wide one.

## Tools

| Tool | Purpose |
|---|---|
| `google_accounts` | List connected accounts, active one, scopes, token health |
| `google_sheets_read` | Spreadsheet metadata (tabs, grid) + values for A1 ranges |
| `google_sheets_write` | Write values/formulas into one or more ranges (batch) |
| `google_sheets_batch` | Raw `spreadsheets.batchUpdate` (formatting, tabs, merges, filters) |
| `google_sheets_create` | New spreadsheet, optional named tabs |
| `google_docs_read` | Doc as text; `include_structure` adds paragraph indexes and styles |
| `google_docs_write` | Raw `documents.batchUpdate`, or text with mode append/replace |
| `google_docs_create` | New doc with optional body text |
| `google_drive_search` | Drive search: name, MIME type, parent, full text, or a raw query |
| `google_drive_read` | Any file by ID/URL/name; Docs → Markdown, Sheets → tabs + ranges |
| `google_drive_export` | Export to a local path (md/txt/pdf/docx, csv/tsv/xlsx, pptx) |
| `google_drive_write` | create_folder, rename, move, copy, share, upload, trash, untrash, delete |
| `google_api` | Escape hatch for Gmail, Calendar, Tasks, or API corners the tools above miss |

File arguments accept an ID, a `docs.google.com`/`drive.google.com` URL, or an exact
name — a name that matches several files fails with the candidates rather than guessing.

## Colab notebooks

A Colab notebook is an ordinary `.ipynb` file in Drive: there is no notebook-creation API
the way there is a Docs or Sheets one (Google's Colab API `colaboratory.googleapis.com` is
allowlist-beta and manages *runtimes*, not files). Creating one therefore means writing the
notebook JSON and uploading it as `application/vnd.google.colaboratory` — which is the
type `google_drive_write` picks for `.ipynb`, and the thing that makes Drive answer with a
`colab.research.google.com/drive/<id>` link instead of a generic file link.

The agent can loop on one: `google_drive_read` returns the notebook JSON, and
`google_drive_write` with `update_content` replaces those bytes in place, keeping the
file's id, link and sharing. Running the cells still happens in the browser — Drive APIs
cannot execute a notebook.

## Where things live

`$PI_CODING_AGENT_DIR/google/` (default `~/.pi/agent/google/`), directory `0700`:

- `client.json` — your OAuth client id and secret, mode `0600`.
- `accounts.json` — per-account refresh/access tokens, granted scopes, active email, mode `0600`.

Neither file is tracked by Git, managed by Home Manager, or printed by Pi. Tokens are
refreshed automatically 60 s before expiry, and one refresh per account runs at a time.

## Notes and troubleshooting

- **`invalid_grant` on refresh.** Usual cause: a consent screen in Testing expires refresh
  tokens after 7 days (personal Gmail projects especially). Publish the consent screen, or
  re-run `/google add`. The account is flagged `needs re-auth` in `/google status` and in
  `google_accounts` rather than failing silently.
- **`redirect_uri_mismatch`.** Register `http://127.0.0.1:8765/callback` on the client, or use
  a Desktop-application client. The extension binds 8765 first and walks upward if it is taken.
- **`access_denied` on a Workspace account.** The admin blocks third-party OAuth clients; the
  personal account still works.
- **403 with a scope hint.** Re-authenticate that account with the scope it needs
  (`/google add --scopes=drive,sheets,docs,…`); `google_api` cannot use a scope never granted.
- **Sign-in opened the wrong browser profile.** The notification always contains the full
  authorization URL, so it can be pasted anywhere.
- **What the model can reach.** Tokens are never exposed to tools, but every read tool runs on
  the account's actual Drive, and `google_drive_write`/`google_api` can change real files and
  sharing. Flip those two rules to `"ask"` in `modules/core.nix` to confirm each call — note
  that `"ask"` blocks headless runs (subagents, `pi -p`).

Verified: account store, PKCE/loopback sign-in, scope handling, account switching, tool
registration and request shaping against stubbed Google endpoints (`tsc --noEmit` clean,
plus a harness that drives the real sign-in flow). Verified live, read-only: token refresh,
identity scopes, Drive listing and Sheets metadata for a connected Workspace account
(`/tmp/gws-check/live-check.mjs`). Not yet exercised live: every writing tool — the first
real write is the first test of it.
