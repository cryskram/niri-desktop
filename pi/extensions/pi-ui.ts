/**
 * pi-ui — useful dev widgets + click utility (replaces duplicate fleet hint).
 *
 * Powerline footer (pi-powerline-footer) already shows: git +/*/?, thinking-level,
 * context gauge, tokens, model. So this widget does NOT duplicate those.
 *
 * What this widget DOES (aboveEditor, not below — powerline owns below):
 * - Persistent hint for /devkit (one-key Nix/git/fleet utilities)
 * - Live fleet count (active async runs from pi-subagents) + devenv/direnv presence
 * - Todo hint when rpiv-todo has active items (via widget, not duplicated in footer)
 *
 * Plus:
 * - /devkit command → SelectList overlay (keyboard + mouse) with 1-click dev actions:
 *   nix flake check, dry-build, git status/diff, direnv, herdr, vpn-status
 * - /pi-ui toggle for widget itself
 * - Blue pulse working indicator (uses Tier 1 blue accent #8aadf4)
 *
 * Generic for any project (cwd): no niri-desktop hardcodes, just cwd basename + file probes.
 */

import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const WIDGET_KEY = "pi-ui:devkit";
const POWERLINE_FOOTER_PLACEMENT = "belowEditor"; // powerline owns this, we use aboveEditor

function fleetCount(): number {
  try {
    const dir = `/tmp/pi-subagents-uid-${process.getuid?.() ?? 1000}/async-subagent-runs`;
    return readdirSync(dir).length;
  } catch {
    return 0;
  }
}

function hasDevenv(cwd: string): boolean {
  try {
    return existsSync(join(cwd, "devenv.nix")) || existsSync(join(cwd, ".envrc"));
  } catch {
    return false;
  }
}

function buildWidgetLines(theme: any, cwd: string): string[] {
  const accent = (s: string) => theme.fg("accent", s);
  const muted = (s: string) => theme.fg("muted", s);
  const dim = (s: string) => theme.fg("dim", s);
  const success = (s: string) => theme.fg("success", s);

  const name = cwd.split("/").pop() || cwd;
  const fc = fleetCount();
  const fleet = fc === 0 ? dim("fleet idle") : success(`fleet ${fc} running`);
  const dev = hasDevenv(cwd) ? success("devenv") : dim("no devenv");
  // AboveEditor so it doesn't stack under powerline + FleetView (both belowEditor on 1080p)
  return [
    `${accent("▎")} ${muted(name)} ${dim("·")} ${fleet} ${dim("·")} ${dev} ${dim("·")} ${accent("/devkit")} ${dim("→ check | build | git | fleet")} ${dim("·")} ${muted("/pi-ui toggle")}`,
  ];
}

export default function piUiExtension(pi: ExtensionAPI) {
  let widgetEnabled = true;

  pi.on("session_start", async (_event, ctx) => {
    try {
      ctx.ui.setWorkingIndicator({
        frames: [
          ctx.ui.theme.fg("dim", "·"),
          ctx.ui.theme.fg("muted", "•"),
          ctx.ui.theme.fg("accent", "●"),
          ctx.ui.theme.fg("accent", "◆"),
        ],
        intervalMs: 120,
      });
    } catch {}
    try {
      ctx.ui.setWidget(WIDGET_KEY, buildWidgetLines(ctx.ui.theme, ctx.cwd), {
        placement: "aboveEditor",
      });
    } catch {}
  });

  // Keep widget fresh on cwd/model changes
  pi.on("agent_start" as any, async (_e, ctx) => {
    if (!widgetEnabled) return;
    try {
      ctx.ui.setWidget(WIDGET_KEY, buildWidgetLines(ctx.ui.theme, ctx.cwd), {
        placement: "aboveEditor",
      });
    } catch {}
  });

  pi.registerCommand("pi-ui", {
    description: "Toggle pi-ui devkit widget (above editor)",
    handler: async (_args, ctx) => {
      widgetEnabled = !widgetEnabled;
      if (widgetEnabled) {
        ctx.ui.setWidget(WIDGET_KEY, buildWidgetLines(ctx.ui.theme, ctx.cwd), {
          placement: "aboveEditor",
        });
        ctx.ui.notify("pi-ui widget: on (above editor) — powerline footer stays below", "info");
      } else {
        ctx.ui.setWidget(WIDGET_KEY, undefined);
        ctx.ui.notify("pi-ui widget: off — footer-only mode", "info");
      }
    },
  });

  // The useful part: click/keyboard dev utility palette
  pi.registerCommand("devkit", {
    description: "Dev utility palette — Nix checks, dry-build, git, fleet, vpn (SelectList overlay)",
    handler: async (_args, ctx) => {
      // Import pi-tui lazily (pi bundles it, no extra npm)
      const tuiMod = await import("@earendil-works/pi-tui").catch(() => null as any);
      if (!tuiMod) {
        ctx.ui.notify("pi-tui not available — run: nix flake check | nixos-rebuild dry-build --flake .#nixos | git status", "warning");
        return;
      }
      const { SelectList } = tuiMod as any;

      type Item = { value: string; label: string; description: string; action: () => Promise<void> };
      const runBash = async (cmd: string, label: string) => {
        ctx.ui.notify(`Running: ${cmd}`, "info");
        try {
          const { spawn } = await import("node:child_process");
          const proc: any = spawn("bash", ["-lc", cmd], { cwd: ctx.cwd });
          let out = "";
          proc.stdout?.on("data", (d: Buffer) => (out += d.toString()));
          proc.stderr?.on("data", (d: Buffer) => (out += d.toString()));
          await new Promise<void>((res) => proc.on("close", () => res()));
          const preview = out.trim().slice(0, 2000) || "(no output)";
          ctx.ui.notify(`${label} done — ${preview.slice(0, 120)}`, out.includes("error") ? "warning" : "info");
          // Also show in a follow-up overlay with full output? For now notify is enough (widget stays).
          // For longer output, open a read-only overlay:
          if (out.length > 400) {
            await ctx.ui.custom<string | null>((tui: any, theme: any, _kb: any, done: any) => {
              const lines = out.split("\n").slice(0, 60);
              const content = lines.join("\n");
              // Minimal Text component for output
              const { Text } = tuiMod as any;
              const comp = new Text(theme.fg("muted", content), 0, 0);
              // Need a container that handles input: any key closes
              return {
                render: (w: number) => [`${theme.fg("accent", "─ " + label + " ─")}`, ...comp.render(w), theme.fg("dim", "Press Esc / Enter to close")],
                handleInput: (data: string) => {
                  if (data.includes("\x1b") || data === "\r" || data === "\n") done(null);
                },
                invalidate: () => {},
              };
            }, { overlay: true, overlayOptions: { width: "90%", height: "80%", border: true } } as any);
          }
        } catch (e: any) {
          ctx.ui.notify(`${label} failed: ${e?.message ?? String(e)}`, "error");
        }
      };

      const items: Item[] = [
        { value: "check", label: "nix flake check (validate)", description: "Validate + niri config", action: () => runBash("nix flake check 2>&1 | tail -n 50", "flake check") },
        { value: "dry", label: "nixos-rebuild dry-build", description: "Build dry-run (what compiles?)", action: () => runBash("nixos-rebuild dry-build --flake .#nixos 2>&1 | tail -n 80", "dry-build") },
        { value: "git", label: "git status", description: "git status -sb + diff stat", action: () => runBash("git status -sb; echo '---'; git diff --stat | head -n 30", "git status") },
        { value: "fleet", label: "subagents fleet / doctor", description: "Show active async runs", action: async () => {
            const c = fleetCount();
            ctx.ui.notify(c === 0 ? "Fleet: idle (no async runs)" : `Fleet: ${c} run(s) — use /subagents-fleet to inspect`, "info");
          }
        },
        { value: "vpn", label: "vpn-status + display", description: "vpn-status & niri outputs", action: () => runBash("vpn-status 2>&1; echo '---'; niri msg outputs 2>&1 | head -n 40", "vpn/display") },
        { value: "devenv", label: "devenv / direnv", description: "devenv test or direnv status", action: () => runBash("if [ -f devenv.nix ]; then devenv test 2>&1 | tail -n 40; else direnv status 2>&1 | head -n 40; fi", "devenv") },
      ];

      const picked: string | null = await ctx.ui.custom<string | null>((tui: any, theme: any, _kb: any, done: any) => {
        const list = new SelectList({
          items: items.map((it) => ({ value: it.value, label: it.label, description: it.description })),
          theme,
          // Use tui.requestRender on change
          onSelect: (v: string) => done(v),
          onCancel: () => done(null),
        } as any);
        // Render via container border
        const { Container, DynamicBorder, Text } = tuiMod as any;
        const container: any = new Container();
        const border: any = new DynamicBorder((s: string) => theme.fg("accent", s));
        const title: any = new Text(theme.fg("accent", " DevKit — pick a dev action (↑↓ Enter, Esc cancel) ") + theme.fg("dim", " — Nerd Font icons if available"), 0, 0);
        container.addChild(border);
        container.addChild(title);
        container.addChild(list);
        // Footer hint
        container.addChild(new Text(theme.fg("dim", " Powerline footer below stays live · Widget aboveEditor · /pi-ui to hide hint"), 0, 0));
        return {
          render: (w: number) => container.render(w),
          handleInput: (data: string) => {
            (list as any).handleInput?.(data);
            tui.requestRender();
          },
          invalidate: () => (list as any).invalidate?.(),
        };
      }, { overlay: true, overlayOptions: { width: "65%", height: "55%", border: true, anchor: "center" } } as any);

      if (!picked) return;
      const hit = items.find((i) => i.value === picked);
      if (hit) await hit.action();
      // Refresh widget after action (fleet count may have changed, etc.)
      if (widgetEnabled) {
        try { ctx.ui.setWidget(WIDGET_KEY, buildWidgetLines(ctx.ui.theme, ctx.cwd), { placement: "aboveEditor" }); } catch {}
      }
    },
  });
}
