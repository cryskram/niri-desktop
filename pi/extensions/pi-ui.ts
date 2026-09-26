/**
 * pi-ui — Tier 3 custom UI for Pi (generic, any cwd).
 *
 * Complements zentui rather than replacing it:
 * - zentui owns the footer (starship) via declarative zentui.json (Tier 2)
 * - this extension owns a lightweight widget + working indicator + command,
 *   using only ctx.ui APIs and pi-tui theme helpers. No second renderer.
 *
 * Provides:
 * - Persistent widget below editor (fleet/context hint + quick keys)
 * - Themed working indicator (Catppuccin blue pulse)
 * - /pi-ui command to toggle widget
 *
 * Works in any project: reads cwd from ctx, git branch via footerData if available,
 * and respects current theme (blue accent from Tier 1).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const WIDGET_KEY = "pi-ui:hint";

function buildWidgetLines(theme: any, cwd: string, modelId: string | undefined): string[] {
  const accent = (s: string) => theme.fg("accent", s);
  const muted = (s: string) => theme.fg("muted", s);
  const dim = (s: string) => theme.fg("dim", s);

  const basename = cwd.split("/").pop() || cwd;
  const model = modelId || "muse-spark";
  // Short hint — show on 1920x1080 without duplicating Noctalia bar
  return [
    `${accent("▎")} ${muted(basename)} ${dim("·")} ${accent(model)} ${dim("·")} ${muted("fleet:")} ${dim("scout/reviewer/oracle ready")} ${dim("·")} ${muted("/pi-ui to toggle")}`,
  ];
}

export default function piUiExtension(pi: ExtensionAPI) {
  let widgetEnabled = true;

  pi.on("session_start", async (_event, ctx) => {
    // Themed working indicator — Catppuccin blue pulse (complements thinkingHigh lavender)
    // Keeps pi's native spinner but gives it a blue accent vs mauve headings
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
    } catch {
      // best-effort, no hard failure
    }

    // Initial widget below editor — fleet hint (generic, any cwd)
    try {
      const lines = buildWidgetLines(ctx.ui.theme, ctx.cwd, ctx.model?.id);
      ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "belowEditor" });
    } catch {
      // widget is optional
    }
  });

  pi.on("agent_start", async (_event, ctx) => {
    if (!widgetEnabled) return;
    try {
      const lines = buildWidgetLines(ctx.ui.theme, ctx.cwd, ctx.model?.id);
      ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "belowEditor" });
    } catch {}
  });

  // Allow pi to refresh widget on model change (theme already handled by pi)
  pi.on("model_change" as any, async (_event, ctx) => {
    if (!widgetEnabled) return;
    try {
      const lines = buildWidgetLines(ctx.ui.theme, ctx.cwd, ctx.model?.id);
      ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "belowEditor" });
    } catch {}
  });

  pi.registerCommand("pi-ui", {
    description: "Toggle pi-ui widget (Tier 3) — fleet hint below editor",
    handler: async (_args, ctx) => {
      widgetEnabled = !widgetEnabled;
      if (widgetEnabled) {
        const lines = buildWidgetLines(ctx.ui.theme, ctx.cwd, ctx.model?.id);
        ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "belowEditor" });
        ctx.ui.notify("pi-ui widget: on (below editor)", "info");
      } else {
        ctx.ui.setWidget(WIDGET_KEY, undefined);
        ctx.ui.notify("pi-ui widget: off", "info");
      }
    },
  });
}
