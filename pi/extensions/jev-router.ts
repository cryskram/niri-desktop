/**
 * Jev router — opencode-go cost & intelligence aware
 *
 * Virtual model `jev/auto` (also `opencode-go/auto` alias) that routes each
 * request to one of 5 opencode-go models using the TypeSafe Jev classifier:
 *
 *   muse-spark-1.3-contributor | gpt-6-luna | deepseek-v4.1-flash
 *   | glm-5.3-flash | mimo-v2.6-flash
 *
 * Costs (per 1M, from opencode.ai/docs/go + pi models-store.json):
 *   muse-spark-1.3-contributor  $0.10 in / $0.20 out / $0.002 cached  (cheapest, 226k req/mo, 1M ctx, 131k out)
 *   mimo-v2.6-flash             $0.14 in / $0.28 out / $0.0028 cached (fast trivial, 150k req/mo)
 *   glm-5.3-flash               $0.15 in / $0.50 out / $0.03 cached   (balanced flash)
 *   deepseek-v4.1-flash         $0.15 in / $0.60 out / $0.003 cached  (384k maxTokens — longest output)
 *   gpt-6-luna                  $0.10 in / $0.50 out / $0.01 cached   (≤272k; $0.20/$0.75 above, 21k req/mo, 1M ctx)
 *
 * Intelligence / task affinity (observed):
 *   muse-spark-1.3  — best agentic tool use, strong coding, cheapest. Default workhorse.
 *   gpt-6-luna      — highest reasoning for complex / cross-cutting / hard debug.
 *   deepseek-v4.1   — best for bulk generation / 384k output / math heavy.
 *   glm-5.3-flash   — balanced flash, vision-capable, good for mixed media.
 *   mimo-v2.6-flash — fastest/cheapest for trivial Q&A, summarization.
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

import type { Message } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
  ModelRoute,
  ModelRouteRequest,
} from "@earendil-works/pi-coding-agent";

const PROVIDER = "opencode-go" as const;

// Model IDs must match models-store.json exactly
const MUSE = "muse-spark-1.3-contributor";
const GPT6_LUNA = "gpt-6-luna";
const DEEPSEEK = "deepseek-v4.1-flash";
const GLM_FLASH = "glm-5.3-flash";
const MIMO_FLASH = "mimo-v2.6-flash";

type TargetId = typeof MUSE | typeof GPT6_LUNA | typeof DEEPSEEK | typeof GLM_FLASH | typeof MIMO_FLASH;

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

  // Trivial / chat / summarization → mimo (fastest, $0.14/$0.28, 150k req/mo)
  if (comp === "trivial" || task.includes("chat") || task.includes("trivial")) {
    return MIMO_FLASH;
  }

  // Complex / architectural / hard debug → gpt-6-luna (higher intelligence, $0.10/$0.50 ± tier)
  if (comp === "complex") return GPT6_LUNA;

  // Standard coding / agentic work → muse (cheapest $0.10/$0.20, best tool discipline)
  // reasoning-heavy but not complex → glm as balanced flash
  if (task.includes("reasoning")) return GLM_FLASH;

  return MUSE; // default workhorse
}

async function classifyWithJev(req: Req, ctx: ExtensionContext): Promise<{ target: TargetId; complexity: string; taskKind: string; probs: Record<string, number> } | null> {
  const jev = ctx.modelRegistry.findOfType("classifier", "typesafe", "jev-latest");
  if (!jev) return null;

  const prompt = lastUserText(req.messages).slice(0, 16_000);
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
    { signal: req.signal },
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

  return { target: pickTarget(complexity, taskKind, cAns.probabilities as Record<string, number>), complexity, taskKind, probs };
}

export default function (pi: ExtensionAPI) {
  const def = {
    provider: "jev",
    id: "auto",
    name: "Auto (Jev) — opencode-go cost aware",
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
        const id = sticky.model.id as TargetId;
        const known: TargetId[] = [MUSE, GPT6_LUNA, DEEPSEEK, GLM_FLASH, MIMO_FLASH];
        if (sticky.model.provider === PROVIDER && known.includes(id)) {
          return routeTo(req, ctx, id, req.state);
        }
      }

      // already classified this branch → reuse (no extra Jev cost/latency)
      if (req.state?.target) {
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
}
