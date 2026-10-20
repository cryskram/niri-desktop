/**
 * Jev router — opencode-go cost & intelligence aware
 *
 * Virtual model `jev/auto` (also `opencode-go/auto` alias) that routes each
 * request to one of 4 opencode-go models using the TypeSafe Jev classifier:
 *
 *   muse-spark-1.3-contributor | gpt-6-luna | deepseek-v4.1-flash
 *   | glm-5.3-flash
 *
 * Costs (per 1M, from opencode.ai/docs/go + pi models-store.json):
 *   muse-spark-1.3-contributor  $0.10 in / $0.20 out / $0.002 cached  (cheapest, 226k req/mo, 1M ctx, 131k out)
 *   glm-5.3-flash               $0.15 in / $0.50 out / $0.03 cached   (balanced flash)
 *   deepseek-v4.1-flash         $0.15 in / $0.60 out / $0.003 cached  (384k maxTokens — longest output; also serves trivial)
 *   gpt-6-luna                  $0.10 in / $0.50 out / $0.01 cached   (≤272k; $0.20/$0.75 above, 21k req/mo, 1M ctx)
 *
 * Compaction (session_before_compact, below): Jev classifies the history being
 * summarized and picks the cheapest adequate summarizer — complex histories get
 * gpt-6-luna's reasoning, reasoning-heavy ones glm-5.3-flash, everything else the
 * cheapest muse. Summaries run at low reasoning with no cache writes (one-off
 * prompt, same as pi's built-in path), instead of inheriting the session's high
 * thinking level. File lists are merged cumulatively (including the previous
 * compaction's, which pi skips for extension summaries) so repeated compactions
 * keep accumulating read/modified files exactly like the built-in one. Any
 * failure falls back to pi's default compaction (which routes direct → muse).
 *
 * Intelligence / task affinity (observed):
 *   muse-spark-1.3  — best agentic tool use, strong coding, cheapest. Default workhorse.
 *   gpt-6-luna      — highest reasoning for complex / cross-cutting / hard debug.
 *   deepseek-v4.1   — bulk generation / 384k output / math heavy + trivial Q&A.
 *   glm-5.3-flash   — balanced flash, vision-capable, good for mixed media.
 *
 * Routing:
 *   - Jev classifies `complexity` (trivial/standard/complex) and `task_kind`
 *     (coding/reasoning/generation/chat). Result cached in router state so we
 *     pay the Jev latency once per session branch.
 *   - Sticky routing for continuations/retries preserves prompt-cache & thinking
 *     signatures (per virtual-models.md).
 *   - Fallback when Jev unavailable → muse-spark-1.3-contributor.
 *
 * Declarative: this file lives in ~/niri-desktop/pi/extensions/ and is wired
 * via modules/core.nix `programs.pi.coding-agent.extensions`. No imperative
 * copy into ~/.pi/agent. After `nixos-rebuild switch`, select with:
 *   pi --model jev/auto   or   /model → jev/auto
 *
 * Requires: TYPESAFE_API_KEY (via /login → typesafe) + opencode-go API key.
 */

import { uuidv7, type Message } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
  ModelRoute,
  ModelRouteRequest,
} from "@earendil-works/pi-coding-agent";
import {
  convertToLlm,
  serializeConversation,
} from "@earendil-works/pi-coding-agent";

const PROVIDER = "opencode-go" as const;

/** Status key published for the footer (consumed by whatever UI shows
 * extension statuses — powerline customItems when that footer is active). */
const STATUS_KEY = "jev-route";

// Model IDs must match models-store.json exactly
const MUSE = "muse-spark-1.3-contributor";
const GPT6_LUNA = "gpt-6-luna";
const DEEPSEEK = "deepseek-v4.1-flash";
const GLM_FLASH = "glm-5.3-flash";

/** Short footer labels — one glance per routed model. */
const SHORT: Record<string, string> = {
  [MUSE]: "muse-1.3",
  [GPT6_LUNA]: "gpt-6-luna",
  [DEEPSEEK]: "deepseek-v4.1",
  [GLM_FLASH]: "glm-5.3-flash",
};

// Back-compat: old branches may persist a mimo target in router state.
// Resolve it to deepseek so resumed sessions keep routing cleanly.
const LEGACY_MIMO = "mimo-v2.6-flash";

type TargetId = typeof MUSE | typeof GPT6_LUNA | typeof DEEPSEEK | typeof GLM_FLASH;

interface JevRouterState {
  target: TargetId;
  complexity: string;
  taskKind: string;
  // keep original Jev probs for debugging / future weighting
  probs?: Record<string, number>;
}

type Req = ModelRouteRequest<JevRouterState>;

function routeTo(req: Req, ctx: ExtensionContext, id: TargetId, state?: JevRouterState): ModelRoute<JevRouterState> {
  const model = ctx.modelRegistry.find(PROVIDER, id);
  if (!model) throw new Error(`Model ${PROVIDER}/${id} not in catalog — check opencode-go auth / models-store.json`);
  // Optimistic footer: show the dispatched model as soon as the prompt is
  // sent, not just after the answer lands via `message_end`. Guarded so
  // headless modes (print/rpc/json) never break routing.
  try {
    (ctx as unknown as { ui?: { setStatus?: (k: string, v: string | undefined) => void } }).ui?.setStatus?.(STATUS_KEY, SHORT[id] ?? id);
  } catch {
    // Footer bookkeeping must never fail the route.
  }
  // pass through the user's thinking level; pi will clamp to the model's map
  return { model, thinkingLevel: req.thinkingLevel, state };
}

function lastUserText(messages: readonly Message[]): string {
  const last = messages.filter((m) => m.role === "user").at(-1);
  if (!last?.content) return "";
  if (typeof last.content === "string") return last.content;
  return last.content
    .filter((b): b is { type: "text"; text: string } => b.type === "text")
    .map((b) => b.text)
    .join("\n");
}

function editedThisTurn(messages: readonly Message[]): boolean {
  const lastUser = messages.findLastIndex((m) => m.role === "user");
  return messages.slice(lastUser + 1).some((m) => m.role === "toolResult" && !m.isError && (m.toolName === "edit" || m.toolName === "write"));
}

// Map Jev answers → target. Costs are secondary to capability; muse is cheapest
// so we default to it unless Jev signals a specialty.
function pickTarget(complexity: string, taskKind: string, probs: Record<string, number>): TargetId {
  const comp = complexity.toLowerCase();
  const task = taskKind.toLowerCase();

  // Long bulk generation → deepseek (384k maxTokens vs 131k/128k others)
  if (task.includes("generation") || task.includes("bulk") || task.includes("long")) {
    // but if also complex, prefer gpt6 for reasoning + generation
    if (comp === "complex" && (probs.complex ?? 0) > 0.7) return GPT6_LUNA;
    return DEEPSEEK;
  }

  // Trivial / chat / summarization → deepseek ($0.15/$0.60, 130k req/mo).
  // Outputs here are short, so the higher per-token output price barely
  // registers in absolute cost, and 1M context keeps cache hits cheap.
  if (comp === "trivial" || task.includes("chat") || task.includes("trivial")) {
    return DEEPSEEK;
  }

  // Complex / architectural / hard debug → gpt-6-luna (higher intelligence, $0.10/$0.50 ± tier)
  if (comp === "complex") return GPT6_LUNA;

  // Standard coding / agentic work → muse (cheapest $0.10/$0.20, best tool discipline)
  // reasoning-heavy but not complex → glm as balanced flash
  if (task.includes("reasoning")) return GLM_FLASH;

  return MUSE; // default workhorse
}

async function classifyText(
  prompt: string,
  ctx: ExtensionContext,
  signal?: AbortSignal,
): Promise<{ complexity: string; taskKind: string; probs: Record<string, number> } | null> {
  const jev = ctx.modelRegistry.findOfType("classifier", "typesafe", "jev-latest");
  if (!jev) return null;
  if (!prompt.trim()) return null;

  const result = await ctx.modelRegistry.classify(
    jev,
    {
      state: { prompt },
      questions: {
        complexity: {
          type: "choice",
          instructions: "How demanding is the software engineering work requested in `prompt` for the cheapest capable model?",
          criteria: {
            trivial: "Quick Q&A, summarization, single-line fix, or low-stakes lookup — any flash model can do it",
            standard: "Ordinary feature, bug fix, single-file edit, or routine code review",
            complex: "Subtle design, cross-cutting change, hard debugging, multi-file architecture, or high-risk migration",
          },
        },
        task_kind: {
          type: "choice",
          instructions: "What kind of work dominates `prompt`?",
          criteria: {
            chat: "Conversational Q&A, explanation, or summarization with no code generation",
            coding: "Agentic coding with tool calls (read/edit/bash/test)",
            reasoning: "Deep reasoning, planning, or trade-off analysis before coding",
            generation: "Bulk code/content generation expecting very long output (>50k tokens)",
          },
        },
      },
    },
    { signal },
  );

  if (result.stopReason !== "stop") return null;

  const cAns = result.answers.complexity;
  const tAns = result.answers.task_kind;
  if (cAns?.type !== "choice" || tAns?.type !== "choice") return null;

  // Pick label with highest probability
  let complexity = "standard";
  let maxP = -1;
  for (const [k, v] of Object.entries(cAns.probabilities)) {
    if ((v ?? 0) > maxP) {
      maxP = v ?? 0;
      complexity = k;
    }
  }
  let taskKind = "coding";
  maxP = -1;
  for (const [k, v] of Object.entries(tAns.probabilities)) {
    if ((v ?? 0) > maxP) {
      maxP = v ?? 0;
      taskKind = k;
    }
  }

  const probs: Record<string, number> = {
    ...cAns.probabilities as Record<string, number>,
    ...tAns.probabilities as Record<string, number>,
  };

  return { complexity, taskKind, probs };
}

async function classifyWithJev(req: Req, ctx: ExtensionContext): Promise<{ target: TargetId; complexity: string; taskKind: string; probs: Record<string, number> } | null> {
  const prompt = lastUserText(req.messages).slice(0, 16_000);
  const classified = await classifyText(prompt, ctx, req.signal);
  if (!classified) return null;
  return {
    ...classified,
    target: pickTarget(classified.complexity, classified.taskKind, classified.probs),
  };
}

// Map Jev answers → compaction summarizer. Unlike live routing, summary output
// is short and bounded, so input price dominates and muse (cheapest everywhere)
// is the default; Jev only promotes histories that need better reasoning.
function pickSummarizer(complexity: string, taskKind: string): TargetId {
  if (complexity.toLowerCase() === "complex") return GPT6_LUNA;
  if (taskKind.toLowerCase().includes("reasoning")) return GLM_FLASH;
  return MUSE;
}

// Jev's context is 64k; sample head (goal) + tail (recent progress) so both
// survive truncation.
function sampleForClassification(full: string, budget = 16_000): string {
  if (full.length <= budget) return full;
  const half = Math.floor(budget / 2);
  return full.slice(0, half) + "\n\n[... middle truncated for classification ...]\n\n" + full.slice(-half);
}

function asStringSet(v: unknown): Set<string> {
  if (v instanceof Set) return new Set([...v].filter((x): x is string => typeof x === "string"));
  if (Array.isArray(v)) return new Set(v.filter((x): x is string => typeof x === "string"));
  return new Set();
}

// Same shape pi uses (`<read-files>` / `<modified-files>` suffix on the summary
// plus matching `details`), reimplemented here because only serializeConversation
// is exported from the package root. Merging the previous compaction's lists by
// hand offsets pi's rule of not carrying file lists forward from extension
// summaries (`fromHook`), so repeated Jev compactions accumulate like built-ins.
function formatFileSuffix(readFiles: string[], modifiedFiles: string[]): string {
  const sections: string[] = [];
  if (readFiles.length > 0) sections.push(`<read-files>\n${readFiles.join("\n")}\n</read-files>`);
  if (modifiedFiles.length > 0) sections.push(`<modified-files>\n${modifiedFiles.join("\n")}\n</modified-files>`);
  if (sections.length === 0) return "";
  return `\n\n${sections.join("\n\n")}`;
}

const SUMMARY_FORMAT = `## Goal
[What is the user trying to accomplish? Can be multiple items if the session covers different tasks.]

## Constraints & Preferences
- [Any constraints, preferences, or requirements mentioned by user]
- [Or "(none)" if none were mentioned]

## Progress
### Done
- [x] [Completed tasks/changes]

### In Progress
- [ ] [Current work]

### Blocked
- [Issues preventing progress, if any]

## Key Decisions
- **[Decision]**: [Brief rationale]

## Next Steps
1. [Ordered list of what should happen next]

## Critical Context
- [Any data, examples, or references needed to continue]
- [Or "(none)" if not applicable]

Keep each section concise. Preserve exact file paths, function names, and error messages.`;

const SUMMARY_SYSTEM_PROMPT =
  "You are a context summarization assistant. Read the conversation and produce a structured summary in the exact format requested. " +
  "Do NOT continue the conversation. Do NOT respond to any questions in it. ONLY output the structured summary.";

export default function (pi: ExtensionAPI) {
  const def = {
    provider: "jev",
    id: "auto",
    name: "Auto <Jev>",
    thinkingLevels: ["low", "medium", "high", "xhigh", "max"] as const,
    contextWindow: 1_048_576, // min of the 5 (1M), shown before first response
    maxTokens: 131_072,
    async route(req: Req, ctx: ExtensionContext): Promise<ModelRoute<JevRouterState>> {
      // direct (compaction summary etc.) → cheapest reliable
      if (req.reason === "direct") return routeTo(req, ctx, MUSE);

      // sticky: continuations and retries stay on the model that handled the turn
      // to preserve prompt cache / thinking signatures
      const sticky = req.failed ?? req.previous;
      if (req.reason !== "user" && sticky) {
        const rawId = sticky.model.id as string;
        // Migrate legacy mimo sticky/state targets to deepseek.
        const id = (rawId === LEGACY_MIMO ? DEEPSEEK : rawId) as TargetId;
        const known: TargetId[] = [MUSE, GPT6_LUNA, DEEPSEEK, GLM_FLASH];
        if (sticky.model.provider === PROVIDER && known.includes(id)) {
          return routeTo(req, ctx, id, req.state);
        }
      }

      // already classified this branch → reuse (no extra Jev cost/latency)
      // Migrate legacy mimo state targets to deepseek.
      if (req.state?.target) {
        if ((req.state.target as string) === LEGACY_MIMO) {
          const migrated: JevRouterState = { ...req.state, target: DEEPSEEK };
          return routeTo(req, ctx, DEEPSEEK, migrated);
        }
        // Optional: after first successful edit, could stay on same model;
        // we keep the original classification to avoid cache miss churn.
        // If you want the Luna promotion pattern (plan → implement), uncomment:
        // if (editedThisTurn(req.messages) && req.state.target === GPT6_LUNA) {
        //   return routeTo(req, ctx, MUSE, { ...req.state, target: MUSE });
        // }
        return routeTo(req, ctx, req.state.target, req.state);
      }

      const classified = await classifyWithJev(req, ctx).catch(() => null);
      if (classified) {
        const state: JevRouterState = {
          target: classified.target,
          complexity: classified.complexity,
          taskKind: classified.taskKind,
          probs: classified.probs,
        };
        return routeTo(req, ctx, classified.target, state);
      }

      // fallback: Jev unavailable → cheapest workhorse (muse)
      return routeTo(req, ctx, MUSE, { target: MUSE, complexity: "standard", taskKind: "coding" });
    },
  };

  pi.registerVirtualModel(def);

  // Optional alias under opencode-go so `opencode-go/auto` also works.
  // Virtual model provider can be any string; this makes discovery easier
  // if users filter by provider.
  pi.registerVirtualModel({ ...def, provider: PROVIDER });

  // Jev-routed compaction: classify the history being summarized and use the
  // cheapest adequate summarizer (complex → gpt-6-luna, reasoning → glm flash,
  // else muse). Runs at low reasoning with no cache writes instead of
  // inheriting the session's thinking level, and merges file lists
  // cumulatively like pi's built-in compaction. Returning undefined (or
  // throwing) falls back to the default summary, which routes direct → muse.
  pi.on("session_before_compact", async (event, ctx) => {
    try {
      const { preparation, branchEntries, customInstructions, signal } = event;
      const allMessages = [
        ...(preparation.messagesToSummarize ?? []),
        ...(preparation.turnPrefixMessages ?? []),
      ];
      if (allMessages.length === 0) return undefined;

      const conversationText = serializeConversation(convertToLlm(allMessages));
      if (!conversationText.trim()) return undefined;

      let summarizer: TargetId = MUSE;
      const classified = await classifyText(sampleForClassification(conversationText), ctx, signal).catch(() => null);
      if (classified) summarizer = pickSummarizer(classified.complexity, classified.taskKind);

      const model = ctx.modelRegistry.find(PROVIDER, summarizer);
      if (!model) return undefined;

      ctx.ui.notify(`Jev compaction: summarizing ${allMessages.length} messages with ${SHORT[summarizer] ?? summarizer}…`, "info");

      const reserve = preparation.settings?.reserveTokens || 16384;
      const maxTokens = Math.min(Math.floor(0.8 * reserve), model.maxTokens > 0 ? model.maxTokens : 8192);

      let promptText = `<conversation>\n${conversationText}\n</conversation>\n\n`;
      if (preparation.previousSummary) {
        promptText +=
          `Update the existing structured summary below with new information. RULES:\n` +
          `- PRESERVE all existing information from the previous summary\n` +
          `- ADD new progress, decisions, and context from the new messages\n` +
          `- UPDATE the Progress section: move items from "In Progress" to "Done" when completed\n` +
          `- UPDATE "Next Steps" based on what was accomplished\n` +
          `- PRESERVE exact file paths, function names, and error messages\n\n` +
          `<previous-summary>\n${preparation.previousSummary}\n</previous-summary>\n\n`;
      } else {
        promptText += `Create a structured context checkpoint summary that another LLM will use to continue the work.\n\n`;
      }
      promptText += `Use this EXACT format:\n\n${SUMMARY_FORMAT}`;
      if (customInstructions) promptText += `\n\nAdditional focus: ${customInstructions}`;

      const response = await ctx.modelRegistry.complete(
        model,
        {
          messages: [
            {
              role: "user" as const,
              content: [{ type: "text" as const, text: promptText }],
              timestamp: Date.now(),
            },
          ],
        },
        {
          maxTokens,
          signal,
          cacheRetention: "none",
          sessionId: uuidv7(),
          // Summaries don't need deep thinking; "low" keeps the one-off call
          // cheap. Same key pi's built-in summarizer sets on its stream path;
          // adapters that don't understand it ignore it harmlessly.
          reasoning: "low",
        },
      );

      // Never persist partial/failed summaries as the session checkpoint.
      if (!response || response.stopReason !== "stop") return undefined;
      if (response.content.some((b) => b.type === "toolCall")) return undefined;
      const summary = response.content
        .filter((b): b is { type: "text"; text: string } => b.type === "text")
        .map((b) => b.text)
        .join("\n");
      if (!summary.trim()) return undefined;

      // Cumulative file lists: preparation.fileOps (this pass) + the previous
      // compaction's details (pi skips extension summaries when accumulating).
      const fileOps = preparation.fileOps as unknown as { read?: unknown; written?: unknown; edited?: unknown } | undefined;
      const read = asStringSet(fileOps?.read);
      const modified = new Set([...asStringSet(fileOps?.written), ...asStringSet(fileOps?.edited)]);
      for (let i = branchEntries.length - 1; i >= 0; i--) {
        const e = branchEntries[i] as unknown as { type?: string; details?: { readFiles?: unknown; modifiedFiles?: unknown } };
        if (e?.type === "compaction" && e.details) {
          for (const f of asStringSet(e.details.readFiles)) read.add(f);
          for (const f of asStringSet(e.details.modifiedFiles)) modified.add(f);
          break;
        }
      }
      const readFiles = [...read].filter((f) => !modified.has(f)).sort();
      const modifiedFiles = [...modified].sort();

      return {
        compaction: {
          summary: summary + formatFileSuffix(readFiles, modifiedFiles),
          firstKeptEntryId: preparation.firstKeptEntryId,
          tokensBefore: preparation.tokensBefore,
          usage: response.usage,
          details: { readFiles, modifiedFiles },
        },
      };
    } catch {
      // Fall back to pi's default compaction (routes direct → muse).
      return undefined;
    }
  });

  // Publish the dispatched physical model for the footer. `message_end`
  // carries the physical `provider`/`model` of the assistant message, so
  // the bar shows what actually answered (e.g. `muse-1.3`). Cleared when
  // the user leaves the router for a plain physical model.
  pi.on("message_end", async (event, ctx) => {
    try {
      const msg = (event as { message?: { role?: string; provider?: string; model?: string } }).message;
      if (!msg || msg.role !== "assistant" || !msg.model) return undefined;
      const selected = (ctx as unknown as { model?: { provider?: string; id?: string } }).model;
      const onRouter =
        (selected?.provider === "jev" && selected?.id === "auto") ||
        (selected?.provider === PROVIDER && selected?.id === "auto");
      if (!onRouter) {
        ctx.ui.setStatus(STATUS_KEY, undefined);
        return undefined;
      }
      if (msg.provider !== PROVIDER) return undefined;
      const label = SHORT[msg.model] ?? msg.model;
      ctx.ui.setStatus(STATUS_KEY, label);
    } catch {
      // Never break the turn on footer bookkeeping.
    }
    return undefined;
  });
}
