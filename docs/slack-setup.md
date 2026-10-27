# Slack in pi — setup for a plain install (no NixOS)

What you get afterward, inside pi:

- read and search Slack (channels, threads, DMs), and post **as yourself** — no bot
  app, no "app was added to the channel" banner
- edit and delete your own messages

Two pieces do this: a Slack MCP server (`korotovsky/slack-mcp-server`) for
read/post, and a small pi extension (`slack-message.ts`) for edit/delete, because
that server has no `chat.update`/`chat.delete` tools. Both use the same credential.

Tested on pi 1.3.x, Node 24, Linux. Nothing here is Nix-specific.

---

## 0. Prerequisites

- `pi` installed and runnable (`pi --version`)
- Node 20+ and npm (for `npx`) — Docker and `go install` alternatives in §3
- A browser where you are logged into the Slack workspace
- Right to post in that workspace (a free workspace works fine)

---

## 1. Copy your browser session credentials

These are the two values that let the tool act as *you*. They are secrets — treat
them like a password.

**`xoxc` token** — open the workspace in Chrome, get onto any
`https://app.slack.com/client/<TEAM_ID>/…` page, then DevTools → Console:

```js
allow pasting
JSON.parse(localStorage.localConfig_v2).teams[document.location.pathname.match(/^\/client\/([A-Z0-9]+)/)[1]].token
```

Copy the printed value (starts with `xoxc-`).

**`xoxd` cookie** — DevTools → Application → Cookies → `https://app.slack.com` →
the cookie named exactly `d` → copy its value (starts with `xoxd-`).

---

## 2. Store them privately and export them

```bash
mkdir -p ~/.secrets && chmod 700 ~/.secrets
umask 077
printf '%s' 'xoxc-PASTE-HERE' > ~/.secrets/slack-xoxc-token
printf '%s' 'xoxd-PASTE-HERE' > ~/.secrets/slack-xoxd-token
ls -l ~/.secrets                                  # expect -rw------- on both
mkdir -p ~/.cache/slack-mcp
```

Add to your shell profile (`~/.zshrc`, `~/.bashrc`, or for fish:
`~/.config/fish/config.fish` with `set -gx`):

```bash
export SLACK_MCP_XOXC_TOKEN="$(cat ~/.secrets/slack-xoxc-token)"
export SLACK_MCP_XOXD_TOKEN="$(cat ~/.secrets/slack-xoxd-token)"
export SLACK_MCP_SECRETS_DIR="$HOME/.secrets"     # used by the edit/delete extension
```

Open a fresh terminal afterwards so `pi` inherits them.

Why the split: the MCP server only reads environment variables, the extension can
read either. Keeping the raw values in files means the profile holds pointers, not
credentials.

---

## 3. Register the MCP server

Easiest path — let pi write the config:

```bash
pi mcp add slack \
  --env SLACK_MCP_XOXC_TOKEN='${SLACK_MCP_XOXC_TOKEN}' \
  --env SLACK_MCP_XOXD_TOKEN='${SLACK_MCP_XOXD_TOKEN}' \
  --env SLACK_MCP_USERS_CACHE="$HOME/.cache/slack-mcp/users_cache.json" \
  --env SLACK_MCP_CHANNELS_CACHE="$HOME/.cache/slack-mcp/channels_cache_v2.json" \
  -- npx -y slack-mcp-server@1.3.0 --transport stdio \
     --enabled-tools channels_list,conversations_history,conversations_replies,conversations_search_messages,users_search,conversations_add_message
```

`${...}` inside single quotes is expanded by pi, not by the shell — that is how the
tokens reach the server without being written into `mcp.json`.

Or edit `~/.pi/agent/mcp.json` by hand:

```json
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": [
        "-y",
        "slack-mcp-server@1.3.0",
        "--transport",
        "stdio",
        "--enabled-tools",
        "channels_list,conversations_history,conversations_replies,conversations_search_messages,users_search,conversations_add_message"
      ],
      "env": {
        "SLACK_MCP_XOXC_TOKEN": "${SLACK_MCP_XOXC_TOKEN}",
        "SLACK_MCP_XOXD_TOKEN": "${SLACK_MCP_XOXD_TOKEN}",
        "SLACK_MCP_USERS_CACHE": "${HOME}/.cache/slack-mcp/users_cache.json",
        "SLACK_MCP_CHANNELS_CACHE": "${HOME}/.cache/slack-mcp/channels_cache_v2.json"
      }
    }
  }
}
```

Other ways to run the same server:

```bash
# Docker
docker run -i --rm -e SLACK_MCP_XOXC_TOKEN -e SLACK_MCP_XOXD_TOKEN \
  ghcr.io/korotovsky/slack-mcp-server:v1.3.0 --transport stdio
# Go
go install github.com/korotovsky/slack-mcp-server/cmd/slack-mcp-server@v1.3.0
```

Notes that save an evening:

- **Pin the version.** `@latest` will move under you, and tool names are what you
  typed in `--enabled-tools`.
- **Never pass `-no-cache`.** Channel-name (`#general`) and DM (`@username_dm`)
  resolution comes from that cache; without it only raw IDs work.
- The cache env vars keep `.users_cache.json` / `.channels_cache_v2.json` out of
  whatever directory `pi` happens to run in.

---

## 4. Verify the connection

```bash
pi mcp list          # expect: slack … connected, 6 tools
```

`npx` downloads the server on first run, so the first check can take ~30s. Then
start `pi` and run `/mcp` — the same status appears in the UI.

---

## 5. Add the edit/delete tools

Copy `slack-message.ts` from the repo (`pi/extensions/slack-message.ts`) to pi's
user extension directory:

```bash
mkdir -p ~/.pi/agent/extensions
cp slack-message.ts ~/.pi/agent/extensions/
```

Restart `pi` (or `/reload`). It needs no build step — pi loads TypeScript
directly, and the comments in the file header referencing `modules/core.nix` are
from the NixOS setup this came from; ignore them.

It reads `SLACK_MCP_SECRETS_DIR` (or the two env tokens) from §2, so there is no
second credential to manage. If you use `pi-guard`, add rules for the two new
tools — `slack_edit_message` should be `allow` and `slack_delete_message` should
be `ask`, otherwise both fall through to the default `ask` and get **blocked** in
headless runs (subagents, `pi -p`).

---

## 6. Use it

Just talk:

| Say | What runs |
|---|---|
| "message Priya that I'll be joining the sync a little late" | `users_search` → `conversations_add_message` to `@priya_dm` |
| "post in #release-notes that 1.4 is out" | `channels_list` → `conversations_add_message` |
| "what did #backend-eng decide about the deploy freeze?" | `conversations_search_messages` |
| "catch me up on my DMs with Rahul" | `conversations_history` on `@rahul_dm` |
| "fix my last message in #release-notes to say 4pm" | history (for `ts`) → `slack_edit_message` |
| "delete the message I just sent to Priya" | history → `slack_delete_message` |

Target formats: `C…`/`D…`/`G…` IDs, `#channel-name`, or `@username_dm` for a
person. For edit/delete, either pass `channel` + `ts` (a timestamp like
`1730000000.123456`) or paste a message permalink
(`https://<workspace>.slack.com/archives/C123ABC/p1730000000123456`) as either
argument.

---

## 7. Things that will bite you

- **Only your own messages** can be edited or deleted. Someone else's comes back as
  `cant_update_message` / `cant_delete_message` — that is a Slack account rule, not
  a missing scope.
- **Deleting leaves a tombstone.** Slack shows "This message was deleted"; nothing
  removes that.
- **Session tokens expire.** Logging out, changing your password, or a forced
  re-auth rotates the `xoxd` cookie → `invalid_auth` at startup. Recopy both values
  and re-export. This is the single most common failure.
- **Enterprise workspaces** sometimes reject the default TLS/User-Agent
  fingerprint: set `SLACK_MCP_USER_AGENT` to your browser's exact UA string and
  `SLACK_MCP_CUSTOM_TLS=true`.
- **These credentials are your whole account**, with no scoped permissions. Don't
  commit them, don't paste them into chats, and keep `chmod 600` on the files.
- Slack's API terms are written around registered apps, so the browser-session
  route is unofficial. If that matters in your organisation, use a proper app
  instead: create one at [api.slack.com/apps](https://api.slack.com/apps), add
  **User Token Scopes** (`search:read`, `channels:history`, `groups:history`,
  `im:history`, `im:write`, `mpim:history`, `mpim:write`, `channels:read`,
  `groups:read`, `im:read`, `mpim:read`, `users:read`, `chat:write`), install it,
  and export the `xoxp-…` token as `SLACK_MCP_XOXP_TOKEN` — everything above then
  works unchanged. A **bot** token (`xoxb`) cannot search, so skip it unless you
  only need reading and posting in channels the bot was invited to.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| `pi mcp list` says slack disconnected, `no Slack credentials`/auth error | `env | grep SLACK_MCP` in the same shell you launch `pi` from; re-export in the profile |
| `Authentication failed - check your Slack tokens` | `xoxd` cookie rotated — recopy `xoxc` + `xoxd` and re-export |
| Search returns nothing | You are on a bot token; `search.messages` is user-token-only |
| `@username_dm` not found | Use the Slack *username*, not the display name; check with `users_search` |
| Edit/delete tools absent | File not in `~/.pi/agent/extensions/`, or pi not restarted |
| Extension fails to load with a module resolution error | Your pi install is older than 1.3 — `slack-message.ts` uses `defineTool` from `@earendil-works/pi-coding-agent`; upgrade pi |
| Edits fail with `cant_update_message` | Message is not yours, or Slack forbids editing that message type |
| Stale channel/user names | Delete `~/.cache/slack-mcp/` and let it rebuild |
| First tool call is slow | `npx` cold start; install the server globally or via Docker/Go to avoid it |
