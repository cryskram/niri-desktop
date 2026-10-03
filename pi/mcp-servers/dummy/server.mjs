#!/usr/bin/env node
// Dummy MCP server — stdio transport, 3 tools + 1 resource
// Purpose: learn how pi-mcp-adapter discovers, lazy-loads, and proxies MCP tools on NixOS.
// Run manually: node ~/niri-desktop/pi/mcp-servers/dummy/server.mjs
// Pi will run it via: command="node", args=["/home/vageesh/niri-desktop/pi/mcp-servers/dummy/server.mjs"]

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

const server = new Server(
  { name: "dummy-mcp", version: "0.1.0" },
  { capabilities: { tools: {}, resources: {} } }
);

// --- Tools ---

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "echo",
      description: "Echo back the input text (tests round-trip). Useful to verify MCP wiring.",
      inputSchema: {
        type: "object",
        properties: { text: { type: "string", description: "Text to echo back" } },
        required: ["text"],
      },
    },
    {
      name: "add",
      description: "Add two numbers. Dummy arithmetic to show typed params.",
      inputSchema: {
        type: "object",
        properties: {
          a: { type: "number", description: "First number" },
          b: { type: "number", description: "Second number" },
        },
        required: ["a", "b"],
      },
    },
    {
      name: "now",
      description: "Return current server time as ISO string. No params — shows zero-arg tools.",
      inputSchema: { type: "object", properties: {} },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === "echo") {
    const parsed = z.object({ text: z.string() }).parse(args);
    return { content: [{ type: "text", text: `echo: ${parsed.text}` }] };
  }

  if (name === "add") {
    const parsed = z.object({ a: z.number(), b: z.number() }).parse(args);
    return { content: [{ type: "text", text: String(parsed.a + parsed.b) }] };
  }

  if (name === "now") {
    return { content: [{ type: "text", text: new Date().toISOString() }] };
  }

  throw new Error(`Unknown tool: ${name}`);
});

// --- Resources (exposed as tools when exposeResources=true, default) ---

server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    {
      uri: "dummy://info",
      name: "dummy-info",
      description: "Static info resource for the dummy MCP",
      mimeType: "text/plain",
    },
  ],
}));

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  if (request.params.uri === "dummy://info") {
    return {
      contents: [
        {
          uri: "dummy://info",
          mimeType: "text/plain",
          text: `dummy-mcp v0.1.0 — running on ${process.platform} via ${process.argv[0]}. If you can read this, pi-mcp-adapter wired correctly.`,
        },
      ],
    };
  }
  throw new Error(`Unknown resource: ${request.params.uri}`);
});

// --- Start stdio transport ---
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[dummy-mcp] started on stdio — tools: echo, add, now | resource: dummy://info");
