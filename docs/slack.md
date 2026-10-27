# Slack in Pi

Pi gets Slack through `korotovsky/slack-mcp-server` (Go, packaged as
`pkgs/slack-mcp-server.nix`, wrapped and declared in `modules/core.nix`). Posting
goes out **as you**, so "message Priya that I'll be late to the sync" is a DM from
your account — not from a bot that Priya has to trust.

Tool calls are gated by the `slack_*` rules in `settings.guard`:
read/search is `allow`, and `slack_conversations_add_message` is `allow` too —
posting goes out as you even headless, so flip it back to `ask` to fail closed.

Setting this up on a machine that is not this NixOS box (or handing it to someone
else)? Use **[docs/slack-setup.md](slack-setup.md)** — the same server and extension
through npm and `pi mcp add`, with no Nix involved.

## Why not Slack's official MCP server

Slack does ship `https://mcp.slack.com/mcp`, and its docs even have a "Connect to
Pi" section. It was still not used here:

| | Official `mcp.slack.com` | This server |
|---|---|---|
| Auth | Confidential OAuth for a registered Slack app (client id **+ secret**) | Browser session (`xoxc`+`xoxd`), or `xoxp` | 
| Slack app | Required, and only **internal or Marketplace-published** apps may use MCP | **None** for the session route |
| Workspace admin | Must **approve the MCP integration** | Nothing to approve |
| Dynamic client registration | Not supported (Pi must be handed a registered client) | n/a |
| `search.messages` | Yes | Yes on any user credential; bot tokens cannot search |

## Setup (no Slack app, no admin)

### 1. Grab your browser session credentials

Log in to the workspace in Chrome.

**`xoxc` token** — DevTools → Console:

1. Type `allow pasting` and press Enter (Chrome blocks pastes into the console).
2. Run this, with the page on `app.slack.com/client/<TEAM_ID>/…`:

   ```js
   JSON.parse(localStorage.localConfig_v2).teams[document.location.pathname.match(/^\/client\/([A-Z0-9]+)/)[1]].token
   ```

3. Copy the printed `xoxc-…` value.

**`xoxd` cookie** — DevTools → Application → Cookies → `https://app.slack.com` →
the cookie literally named `d` → copy its value (`xoxd-…`).

### 2. Write them to the secrets files

Do this in your own terminal. `pi-guard` deliberately refuses agent writes under
`**/secrets/**`, and raw files (not a sourced `.env`) keep the values out of any
shell-evaluation path.

```bash
umask 077
printf '%s' 'xoxc-replace-me' > ~/niri-desktop/secrets/slack-xoxc-token
printf '%s' 'xoxd-replace-me' > ~/niri-desktop/secrets/slack-xoxd-token
ls -l ~/niri-desktop/secrets/slack-{xoxc,xoxd}-token   # expect -rw-------
```

`SLACK_MCP_SECRETS_DIR` relocates the directory; exporting
`SLACK_MCP_XOXC_TOKEN`/`SLACK_MCP_XOXD_TOKEN` skips the files entirely.

### 3. Reload Pi

```
/reload        # or restart pi
/mcp           # "slack" should list 6 tools
```

## Daily use

Ask normally — the model chains `users_search` / `channels_list` to resolve the
target, then posts:

| You say | What happens |
|---|---|
| "message Priya that I'll be joining the sync a little late" | `users_search` → `conversations_add_message` with `channel_id = "@priya_dm"` |
| "post in #release-notes that 1.4 is out" | `channels_list` → `conversations_add_message` with `#release-notes` |
| "what did #backend-eng decide about the deploy freeze?" | `conversations_search_messages` |
| "catch me up on my DMs with Rahul" | `conversations_history` with `@rahul_dm` |

Target formats the server accepts: `C…`/`D…` IDs, `#channel-name`, or
`@username_dm` (the `_dm` suffix is required for a person — that is what maps to
the existing DM conversation). Posting is `allow` here, so it does not prompt.

## Editing and deleting messages

The MCP server has **no** `chat.update` and **no** `chat.delete` — its 18 tools cover
history, search, posting, reactions, unreads, usergroups and saved items, and
v1.3.0 is the latest release. Those two methods therefore come from a small local
extension, `pi/extensions/slack-message.ts`, which reads the *same* credential files
(one Slack setup, not two):

| Tool | Slack method | pi-guard |
|---|---|---|
| `slack_edit_message` | `chat.update` | `allow` |
| `slack_delete_message` | `chat.delete` | `ask` |

```text
slack_edit_message    { channel: "C0AB12CD34E", ts: "1730000000.123456", text: "moved to 4pm" }
slack_edit_message    { ts: "https://tap.slack.com/archives/C0AB12CD34E/p1730000000123456", text: "fixed" }
slack_delete_message  { channel: "C0AB12CD34E", ts: "1730000000.123456" }
```

Just ask: *"fix my last message in #release-notes to say 4pm"*, *"delete the message
I just sent to Priya"*. The model reads the channel first (for the ID and `ts`) and
then calls the tool.

Constraints worth knowing:

- Only **your own** messages. Slack refuses anyone else's with `cant_update_message` /
  `cant_delete_message` — that is an account rule, not a scope problem.
- Channel *names* are not resolved by this extension: `#channel` and `@username_dm`
  resolution lives in the MCP server's caches, so the ID comes from
  `channels_list`/`conversations_history`, or from a permalink.
- Deleting leaves Slack's **"This message was deleted"** tombstone. Nothing removes it.
- Deleting prompts first; in headless runs (subagents, `pi -p`) the `ask` rule blocks
  it outright. Editing does not prompt.

## If you would rather use a proper Slack app (`xoxp`)

Sanctioned, stable, and does not die when you log out of the browser — worth it if
session tokens ever get blocked by a workspace. Create the app, add **User Token
Scopes** (`search:read`, `*:history`, `*:read`, `im:write`, `mpim:write`,
`chat:write`, `users:read`), install it, then:

```bash
umask 077
printf '%s' 'xoxp-replace-me' > ~/niri-desktop/secrets/slack-mcp-token
```

Upstream priority is `xoxp` > `xoxb` > `xoxc/xoxd`, so the app token wins over a
browser session once present — and a **bot** token (`xoxb`) cannot search, because
`search.messages` is user-token-only.

Non-secret knobs live in the `slack` entry in `modules/core.nix` (`env` block, next
to the commented `SLACK_MCP_ADD_MESSAGE_TOOL` example): channel-restricted posting,
`SLACK_MCP_USER_AGENT` / `SLACK_MCP_CUSTOM_TLS` for Enterprise workspaces, and
`SLACK_MCP_LOG_LEVEL`.

## Session-token caveats

- They **expire**: logging out of the browser, changing your password, or a forced
  re-auth rotates the cookie. Symptom is `invalid_auth` at startup — recopy both.
- They are your account's full authority. There is no scope limiting, which is why
  the `ask` gate on posting exists.
- Enterprise workspaces sometimes reject the default TLS/User-Agent fingerprint;
  set `SLACK_MCP_USER_AGENT` to your browser's own string plus
  `SLACK_MCP_CUSTOM_TLS = "true"`.
- Slack's API terms are written around registered apps, so this is undocumented
  territory rather than something Slack approves of. The app route above is the
  clean one.

## Verify the pin after a version bump

Upstream's suite needs a live workspace, so `doCheck` is off; confirm the built
server serves MCP by hand. A real credential is required — it exits with
`invalid_auth` before answering `tools/list`:

```bash
BIN=$(nix build --no-link --print-out-paths --impure --expr \
  'let f = builtins.getFlake (toString /home/vageesh/niri-desktop);
       p = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
   in p.callPackage /home/vageesh/niri-desktop/pkgs/slack-mcp-server.nix {}')/bin/slack-mcp-server
export SLACK_MCP_XOXC_TOKEN="$(cat ~/niri-desktop/secrets/slack-xoxc-token)"
export SLACK_MCP_XOXD_TOKEN="$(cat ~/niri-desktop/secrets/slack-xoxd-token)"
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | "$BIN" --transport stdio | head -c 2000
```

`tools/list` must name the six enabled tools; anything else means the
`--enabled-tools` list in `modules/core.nix` drifted from upstream.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `/mcp` shows slack disconnected, stderr `no Slack credentials …` | Neither secrets pair present/readable; the wrapper exits `78` |
| `Authentication failed - check your Slack tokens` | `xoxd` cookie rotated (logged out / password change), or the app token was revoked |
| Posting asks every time | You set `slack_conversations_add_message = "ask"`; the repo default is `allow`. `ask` blocks headless subagent calls entirely |
| `@username_dm` not found | Wrong handle — `users_search` uses Slack usernames, not display names; caches must be warm (never pass `-no-cache`) |
| `cant_update_message` / `cant_delete_message` | The message is not yours, or Slack does not allow editing that message type |
| Edit/delete tools missing from pi | The extension did not load — check `/reload` and that `../pi/extensions/slack-message.ts` is in `programs.pi.coding-agent.extensions` |
| Channel lookups fail / stale | Delete `~/.cache/slack-mcp/` and let it rebuild |
