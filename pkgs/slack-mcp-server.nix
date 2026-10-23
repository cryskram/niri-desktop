# korotovsky/slack-mcp-server — Slack MCP server (Go) over the Slack Web API.
#
# Why this and not Slack's official remote MCP (https://mcp.slack.com/mcp):
# the official server requires a directory-published or internal Slack app *and*
# workspace-admin approval of the MCP integration, and it authenticates with a
# confidential OAuth client (client id + secret). This one authenticates with a
# plain token, so nothing needs admin approval beyond installing the app itself.
# `search.messages` is a user-token-only method, which is why the xoxp route is
# the interesting one — a bot token can read channels it is in but cannot search.
#
# Token handling is NOT here: modules/core.nix wraps this binary in a script that
# reads ~/niri-desktop/secrets/slack-mcp.env, so no credential can reach the store.
#
# Not in nixpkgs (verified), so the released tag is pinned. Version strings come
# from these ldflags rather than the build's git checkout, which does not exist.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
let
  version = "1.3.0";
in
buildGoModule {
  pname = "slack-mcp-server";
  inherit version;

  src = fetchFromGitHub {
    owner = "korotovsky";
    repo = "slack-mcp-server";
    tag = "v${version}";
    hash = "sha256-I4f6yKV0BXtaxnqi/XNID+Pwl2mWjSqxIHhb07U7sc4=";
  };

  vendorHash = "sha256-+uQRODO9oL8mGKBmdghTxE6R9Fz+3GJFVTi17306gT8=";

  subPackages = [ "cmd/slack-mcp-server" ];

  ldflags = [
    "-s"
    "-w"
    "-X"
    "github.com/korotovsky/slack-mcp-server/pkg/version.Version=v${version}"
    "-X"
    "github.com/korotovsky/slack-mcp-server/pkg/version.BinaryName=slack-mcp-server"
  ];

  # Upstream's suite talks to a live Slack workspace (token + network), so it
  # cannot run in the sandbox. A broken pin therefore surfaces at MCP call time,
  # which is why the version bump is validated by an actual tools/list handshake
  # instead — see docs/slack.md.
  doCheck = false;

  meta = {
    description = "Slack MCP server — search, read and post Slack messages via an xoxp/xoxb token";
    homepage = "https://github.com/korotovsky/slack-mcp-server";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "slack-mcp-server";
  };
}
