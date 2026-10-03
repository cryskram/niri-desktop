# Dummy MCP — pi + NixOS learning harness (now pure Nix)

Minimal stdio MCP server to understand how `pi-mcp-adapter` works with the declarative NixOS setup in `~/niri-desktop`.

## What it does

| Tool | Params | Behaviour |
|------|--------|-----------|
| `dummy_echo` | `text: string` | Returns `echo: <text>` |
| `dummy_add` | `a: number, b: number` | Returns `a+b` |
| `dummy_now` | — | Returns ISO timestamp |
| `dummy_read_dummy_info` (resource) | — | `dummy://info` static text |

All are proxied through the single `mcp` tool — no token burn until used.

## Architecture on this machine

```
pi/mcp-servers/dummy/server.mjs  (your MCP source, tracked in git)
        │
        ├─── pi/packages.nix #dummy-mcp  (Nix derivation, pins npm deps via `withDeps`)
        │         exports /nix/store/...-dummy-mcp-0.1.0/{server.mjs,node_modules}
        │
        └─── modules/core.nix  xdg.configFile."mcp/mcp.json"
                  │
                  └─── ~/.config/mcp/mcp.json  (Home Manager symlink → /nix/store/...-hm_mcpmcp.json)
                            │
                            └─── pi-mcp-adapter reads it as "shared-global standard MCP" source
                                      lazy-spawns: ${pkgs.nodejs}/bin/node /nix/store/.../server.mjs
```

- `pi-mcp-adapter` is `v3.3.0` in `pi/packages.nix`, loaded via `programs.pi.coding-agent.extensions`.
- `pi` exposes **one** `mcp` proxy tool (~200 tokens), not one per MCP tool.
- Servers are **lazy** — no process until you call `mcp({ search/tool })`.

```
mcp({ search: "dummy" })                              // discover
mcp({ tool: "dummy_echo", args: { text: "hi" } })     // call → echo: hi
mcp({ tool: "dummy_add", args: { a: 2, b: 3 } })      // → 5
mcp({ tool: "dummy_now", args: {} })                  // → 2026-10-03T...
```

TUI: `/mcp-adapter` → status panel. `mcp` is also available to subagents.

## How to add YOUR OWN MCP (step-by-step)

### Option A — Pure Nix (recommended, reproducible) — what `dummy` now uses

1. **Create the server** (copy `dummy` as template):

   ```bash
   cp -r pi/mcp-servers/dummy pi/mcp-servers/my-mcp
   # edit pi/mcp-servers/my-mcp/package.json (name/version/deps)
   # edit pi/mcp-servers/my-mcp/server.mjs (your tools/resources)
   ```

   Minimal `package.json`:
   ```json
   { "name": "my-mcp", "version": "0.1.0", "type": "module",
     "dependencies": { "@modelcontextprotocol/sdk": "^1.12.0", "zod": "^3.23.8" } }
   ```

   Install once to generate lockfile (bypass CodeArtifact):
   ```bash
   cd pi/mcp-servers/my-mcp
   npm install --registry https://registry.npmjs.org --ignore-scripts --no-fund --no-audit
   ```

2. **Pin it in `pi/packages.nix`**:

   ```nix
   my-mcp = withDeps {
     pname = "my-mcp";
     version = "0.1.0";
     src = ./mcp-servers/my-mcp;   # relative to pi/packages.nix
     npmHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # fake first
     npmFlags = [ "--omit=dev" ];
   };
   ```

   Get the real hash:
   ```bash
   git add pi/mcp-servers/my-mcp
   nix build .#my-mcp   # fails → prints got: sha256-... → paste it as npmHash
   nix build .#my-mcp   # now passes → /nix/store/...-my-mcp-0.1.0
   ```

3. **Wire it in `modules/core.nix`** (`xdg.configFile."mcp/mcp.json".text`):

   ```nix
   my-mcp = {
     command = "${pkgs.nodejs}/bin/node";
     args = [ "${piPackages.my-mcp}/server.mjs" ];
   };
   ```

   Optional per-server knobs (see pi-mcp-adapter README):
   ```nix
   my-mcp = {
     command = "${pkgs.nodejs}/bin/node";
     args = [ "${piPackages.my-mcp}/server.mjs" ];
     # lifecycle = "lazy";        # default — only start on tool call
     # directTools = true;        # register each tool individually in pi
     # idleTimeout = 10;          # minutes before idle disconnect
   };
   ```

4. **Build & activate**:

   ```bash
   nix flake check
   nixos-rebuild dry-build --flake .#nixos
   sudo nixos-rebuild switch --flake ~/niri-desktop#nixos
   # verify live file
   cat ~/.config/mcp/mcp.json | jq
   ```

5. **Test without restarting pi** (new sessions pick it up automatically):

   ```bash
   pi -p --no-session "Use mcp({search:\"my-mcp\"}) then call my-mcp_echo"
   # or inside pi TUI: /mcp-adapter
   ```

### Option B — Quick local iteration (no Nix rebuild)

Useful while you iterate on `server.mjs` without pinning hashes:

```nix
# modules/core.nix — temporary
my-mcp = {
  command = "node";
  args = [ "/home/vageesh/niri-desktop/pi/mcp-servers/my-mcp/server.mjs" ];
};
```

- Requires `pi/mcp-servers/my-mcp/node_modules` present locally (`npm install --registry https://registry.npmjs.org`).
- Still declarative (path is in the repo), but depends on imperative `node_modules` — convert to Option A before committing.
- Validate with `nix flake check`; the file is still generated to `~/.config/mcp/mcp.json` on next switch.

### Option C — HTTP / OAuth (remote MCP)

For StreamableHTTP servers (like `parallel-search`):

```nix
my-remote = {
  url = "https://mcp.example.com/mcp-oauth";
  protocolVersion = "auto";
  # auth = "oauth";  # triggers browser flow; credentials in OS keychain
  # directTools = true;
};
```

See `modules/core.nix` comments for why `parallel-search` uses `/mcp-oauth` not `/mcp`.

## Manual test (no pi)

```bash
# pure Nix build artifact
node /nix/store/*-dummy-mcp-*/server.mjs   # or result/server.mjs after `nix build .#dummy-mcp`

# local iteration
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}' \
  | node pi/mcp-servers/dummy/server.mjs
```

## Files on this machine

- `pi/mcp-servers/dummy/server.mjs` — source (stdio, 3 tools + 1 resource)
- `pi/mcp-servers/dummy/package.json` + `package-lock.json` — deps, pinned
- `pi/mcp-servers/dummy/.npmrc` — forces `registry.npmjs.org` (avoids CodeArtifact)
- `pi/packages.nix` — `dummy-mcp` derivation (`withDeps` → `/nix/store/...-dummy-mcp`)
- `modules/core.nix` — `xdg.configFile."mcp/mcp.json"` → `~/.config/mcp/mcp.json`
- `.gitignore` — `pi/mcp-servers/dummy/node_modules/` ignored

## Troubleshooting

- **`hash mismatch` on `nix build .#my-mcp`** → copy the `got: sha256-...` into `npmHash`.
- **`Path 'mcp-servers/...' does not exist`** → `git add pi/mcp-servers/...` (flakes only see tracked files).
- **CodeArtifact 401 on `npm install`** → add `registry=https://registry.npmjs.org/` to `pi/mcp-servers/<name>/.npmrc` or pass `--registry https://registry.npmjs.org`.
- **`~/.config/mcp/mcp.json` not updating** → run `sudo nixos-rebuild switch --flake ~/niri-desktop#nixos` (Home Manager symlink is read-only until switch).
- **Tool not found in pi** → `mcp({ search: "<name>" })` forces lazy load; check `/mcp-adapter` status; restart pi session.

