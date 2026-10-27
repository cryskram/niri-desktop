/**
 * Jev router — model choice by measured capability and speed, cost as tie-break
 *
 * Virtual model `jev/auto` (also `opencode-go/auto` alias) that routes each
 * request to one of the opencode-go models using the TypeSafe Jev classifier.
 *
 * Selection is evidence-based. Benchmarks from the "opencode go model league"
 * (nahuelgenchi.com/software/opencode-go-model-league, 20 Oct 2026 — 29 models,
 * 8 benchmarks, blended per-request cost); Intelligence Index and output speed
 * from Artificial Analysis; token prices from pi's models-store.json.
 *
 *   model                  int  t/s    DeepSWE  TB2.1  SciCode  AA-LCR  AA-code   $/req
 *   muse-spark-1.3-contrib  48  114.5     75.4   72.3     58.8    83.0     54.3  $0.00026
 *   mimo-v2.6-pro           46   49.1     71.9   67.8     60.9    86.3      -     $0.00092
 *   claude-haiku-5-5        43  236.0      -      -       55.0    82.7     36.5  $0.00078  (rejected)
 *   deepseek-v4.1-flash     39  233.5     74.2   74.5     51.9    84.0      -     $0.00046
 *   glm-5.3-flash           42   76.2     63.0   62.9     51.6    80.0     71.5  $0.00190
 *   gpt-6-luna              38  122.5     66.6   73.0     54.6    83.3     41.1  $0.00071
 *   kimi-k3                 44   41.2     69.0   80.9     59.5    88.7     51.9  $0.03060
 *   grok-4.7                46   91.5     71.0   73.4     57.4    76.7     56.3  $0.01775
 *
 * What the numbers decided:
 *   - No model on this plan is both faster *and* better at coding than muse
 *     (DeepSWE 75.4 with the best AA coding index among the affordable ones), so
 *     hard coding does not get a different, slower model: it gets more thinking
 *     (effortBand floor → xhigh). gpt-6-luna was dropped as dominated everywhere.
 *   - The symmetric half: the *type* of work matters as much as complexity, so
 *     effort is a band per (task kind × complexity) — bulk chat/generation is
 *     clamped low, coding/reasoning raises it, structural evidence or repeated
 *     tool failures force xhigh. Band clamping only adjusts a turn's thinking
 *     level, never the session's model choice or its history.
 *   - mimo-v2.6-pro is the strongest long-context/coding-science model here
 *     (SciCode 60.9, AA-LCR 86.3) but runs at 49 t/s, so it is kept for
 *     compaction summaries only — one-off calls where latency is not loop-bound.
 *   - Stuck loops stay on muse and raise effort. claude-haiku-5-5 was tried first
 *     (236 t/s, int 43) but adds a fifth model and a second tool-reliability
 *     profile for no measured coding gain; deepseek cannot take this slot because
 *     a stuck loop is tool-driven, which is exactly where it leaks tool calls.
 *   - gemini-4-argon is the raw leader (DeepSWE 77.9, TB4.0 57.58, GPQA 96.4)
 *     but at $4/$20 per 1M and ~$0.028/req it stays out of automatic routing.
 *
 * Prices (per 1M, pi models-store.json):
 *   muse-spark-1.3-contributor  $0.10 in / $0.20 out / $0.002 cached   (226k req/mo, 1M ctx, 131k out, vision)
 *   deepseek-v4.1-flash         $0.15 in / $0.60 out / $0.003 cached   (384k out — longest; vision)
 *   glm-5.3-flash               $0.15 in / $0.50 out / $0.030 cached   (vision)
 *   mimo-v2.6-pro               $0.435 in / $0.87 out / $0.0036 cached (vision; near-free cache)
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
const MIMO_PRO = "mimo-v2.6-pro"; // compaction only: best AA-LCR, but 49 t/s
const DEEPSEEK = "deepseek-v4.1-flash";
const GLM_FLASH = "glm-5.3-flash";

/** Short footer labels — one glance per routed model. */
const SHORT: Record<string, string> = {
  [MUSE]: "muse-1.3",
  [MIMO_PRO]: "mimo-2.6-pro",
  [DEEPSEEK]: "deepseek-v4.1",
  [GLM_FLASH]: "glm-5.3-flash",
};

// Back-compat: old branches may persist a mimo-v2.6-flash target in router
// state. Flash is tool-capable, so resume on the safe workhorse (not deepseek,
// which leaks tool calls, and not the new mimo-v2.6-pro, a different model).
const LEGACY_MIMO = "mimo-v2.6-flash";

type TargetId = typeof MUSE | typeof MIMO_PRO | typeof DEEPSEEK | typeof GLM_FLASH;

interface JevRouterState {
  target: TargetId;
  complexity: string;
  taskKind: string;
  // keep original Jev probs for debugging / future weighting
  probs?: Record<string, number>;
}

type Req = ModelRouteRequest<JevRouterState>;

// Exported for harness testing (same as pickSummarizer/effortBand below).
export function routeTo(
  req: Req,
  ctx: ExtensionContext,
  id: TargetId,
  state?: JevRouterState,
  floor?: ThinkingLevel,
  ceiling?: ThinkingLevel,
): ModelRoute<JevRouterState> {
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
  // pass through the user's thinking level, raised by the turn's effort floor
  // and lowered by its effort ceiling (floor wins on conflict), then snapped to
  // what this model actually offers so pi never clamps it somewhere pricier.
  let level = req.thinkingLevel;
  if (floor && LEVELS.indexOf(level as ThinkingLevel) < LEVELS.indexOf(floor)) level = floor;
  else if (ceiling && LEVELS.indexOf(level as ThinkingLevel) > LEVELS.indexOf(ceiling)) level = ceiling;
  level = snapToModel(level as ThinkingLevel, model as { thinkingLevelMap?: Record<string, unknown> });
  return { model, thinkingLevel: level, state };
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

// Capability-first routing (price only breaks ties). Each target is chosen for
// the *affinity* it is known to be good at:
//   muse      — agentic coding, top-2 DeepSWE, cheapest per request
//   mimo-pro  — compaction only: best AA-LCR (86.3) but 49 t/s, so never in the loop
//   deepseek  — math, Q&A, bulk/long output (384k); leaks tool calls as text, so
//               text-driven turns only
//   glm-flash — balanced flash + vision
//
// Two rules learned the hard way:
//   * deepseek-v4.1-flash leaks tool calls as DSML/XML text instead of structured
//     calls. It is excluded from tool-driven turns (coding, edits, any tool
//     activity) and used where that failure cannot fire: chat, math, bare Q&A,
//     bulk generation.
//   * the classifier only sees one prompt, so structural evidence (code fences,
//     several paths, hard-debug vocabulary) promotes a "standard" verdict —
//     otherwise hard turns would never get their extra thinking.
const HARD_PATTERN =
  /\b(debug|race|deadlock|segfault|flaky|regression|architecture?|architectural|design|migrat\w*|trade-?offs?|optimi[sz]\w*|performance|refactor|root cause|why (?:does|is|doesn't|do))\b/i;

/** Capability ladder: escalate up, never silently downgrade mid-branch. */
const RANK: Record<TargetId, number> = {
  [DEEPSEEK]: 1,
  [GLM_FLASH]: 2,
  [MUSE]: 3,
  [MIMO_PRO]: 0, // compaction-only; never a branch target
};

/** Conversation-derived evidence, independent of Jev's single-prompt verdict. */
export interface RouteSignals {
  prompt: string;
  vision: boolean;
  codeFences: number;
  paths: number;
  toolErrors: number;
  edits: boolean;
}

export function readSignals(messages: readonly Message[], prompt: string): RouteSignals {
  const lastUser = messages.findLastIndex((m) => m.role === "user");
  const tail = lastUser >= 0 ? messages.slice(lastUser + 1) : [];
  const toolResults = tail.filter((m) => m.role === "toolResult");

  const lastUserMessage = messages[lastUser];
  const vision = Array.isArray(lastUserMessage?.content)
    && lastUserMessage.content.some((b) => (b as { type?: string }).type === "image");

  return {
    prompt,
    vision,
    codeFences: (prompt.match(/```/g) ?? []).length >> 1,
    // path-ish tokens: a/b, ./x, src/foo.ts, ~/x — catches multi-file asks
    paths: new Set(prompt.match(/[~.]?\/?(?:[\w.-]+\/)+[\w.-]+/g) ?? []).size,
    toolErrors: toolResults.filter((m) => m.isError).length,
    edits: tail.some((m) => m.role === "toolResult" && !m.isError
      && (m.toolName === "edit" || m.toolName === "write")),
  };
}

/** Structural evidence that a "standard" prompt is really a hard one. */
function looksHard(signals: RouteSignals): boolean {
  return signals.codeFences >= 2
    || signals.paths >= 3
    || (signals.prompt.length > 1200 && HARD_PATTERN.test(signals.prompt))
    || (HARD_PATTERN.test(signals.prompt) && signals.paths >= 2);
}

export function pickTarget(
  taskKind: string,
  probs: Record<string, number>,
  signals: RouteSignals,
): TargetId {
  const taskRaw = taskKind.toLowerCase();
  const task = (probs[taskRaw] ?? 1) >= 0.4 ? taskRaw : "coding";

  // Text-driven turn: no tool work expected, so deepseek's strengths (math, Q&A,
  // 384k output) apply without its tool-call leak firing. `coding` never
  // qualifies — even a trivial coding ask ends in an edit tool call.
  const textWork = (task === "chat" || task === "generation")
    && signals.toolErrors === 0
    && !signals.edits;

  // Images need a vision model.
  if (signals.vision) return GLM_FLASH;

  // Two failed tool calls: stay on muse and raise effort (see effortBand).
  // deepseek is disqualified here — a stuck loop is tool-driven, which is exactly
  // where it leaks tool calls as text — and no other plan model beats muse at
  // coding, so switching model would trade reliability for nothing.

  if (textWork) return DEEPSEEK;

  // Reasoning-first planning that is not agentic yet → glm-flash (best AA coding
  // index 71.5 and math 93.9 on the plan), before tools start moving files.
  if (task === "reasoning") return GLM_FLASH;

  // Everything else — standard *and* hard coding — stays on muse: it is the best
  // coding model on the plan (DeepSWE 75.4, AA-code 54.3) and reasonably fast
  // (114 t/s). Hardness is expressed through effort, not a slower model.
  return MUSE;
}

/** Thinking levels, ascending — used for floor/ceiling comparisons. */
const LEVELS = ["low", "medium", "high", "xhigh", "max"] as const;
export type ThinkingLevel = (typeof LEVELS)[number];

/**
 * Snap a level to one the chosen model actually exposes.
 *
 * The plan's models do not share a ladder: muse supports low/medium/high/xhigh,
 * while glm-5.3-flash and deepseek-v4.1-flash support only low/high/max (no
 * medium, no xhigh). Left to pi, `xhigh` on glm clamps *up* to `max` — verified
 * in a real run — which spends more than the band intended. Nearest-supported
 * with ties broken toward the cheaper level keeps the router in charge:
 * xhigh on glm → high, medium on glm → low. The tie rule is a deliberate cost
 * guard rather than an escalation: on a ladder that lacks a tier, an effort
 * floor lands on the closest supported tier *below* it instead of jumping to
 * `max`.
 */
function snapToModel(level: ThinkingLevel, model: { thinkingLevelMap?: Record<string, unknown> }): ThinkingLevel {
  const map = model?.thinkingLevelMap;
  if (!map) return level; // no map: pi decides
  const supported = LEVELS.filter((l) => map[l] !== null && map[l] !== undefined);
  if (supported.length === 0 || supported.includes(level)) return level;
  const target = LEVELS.indexOf(level);
  let best: ThinkingLevel = supported[0]!;
  let bestDistance = Number.POSITIVE_INFINITY;
  for (const candidate of supported) {
    const distance = Math.abs(LEVELS.indexOf(candidate) - target);
    if (distance < bestDistance
      || (distance === bestDistance && LEVELS.indexOf(candidate) < LEVELS.indexOf(best))) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}

/**
 * Effort band for a turn: (prompt type × complexity) → thinking levels.
 *
 * Since no plan model beats muse at coding, complexity buys *thinking*, not a
 * different model. Type matters as much as complexity: bulk *generation* and
 * *chat* gain little from reasoning tokens, while *coding* and *reasoning* gain
 * a lot — so the same "standard" verdict maps to different bands.
 *
 * The band is applied by clamping the session level (which the user may have
 * set explicitly): the floor raises, the ceiling lowers, and the floor wins on
 * a conflict. Confidence is required per dimension — an uncertain complexity
 * falls back to "standard" (a no-op band), and an uncertain type falls back to
 * "coding", which is the agentic norm here.
 *
 * Structural evidence overrides the labels: several code fences, three-plus
 * paths, hard-debug vocabulary, or two failed tool calls force the xhigh floor
 * even when Jev called the prompt trivial/standard.
 */
export function effortBand(
  taskKind: string,
  complexity: string,
  probs: Record<string, number>,
  signals: RouteSignals,
): { floor?: ThinkingLevel; ceiling?: ThinkingLevel } {
  const c = complexity.toLowerCase();
  const level = (probs[c] ?? 1) >= 0.45 ? c : "standard";
  const taskRaw = taskKind.toLowerCase();
  const task = (probs[taskRaw] ?? 1) >= 0.4 ? taskRaw : "coding";

  // Stuck loops and structurally-hard prompts get maximum reasoning on muse.
  if (looksHard(signals) || signals.toolErrors >= 2) return { floor: "xhigh" };

  switch (task) {
    case "chat":
    case "generation":
      // Explaining, summarizing, or emitting bulk text: thinking adds little
      // beyond a floor. Generation gets a slightly higher floor than chat
      // because long output still needs a plan.
      if (level === "complex") return task === "chat" ? { floor: "high", ceiling: "xhigh" } : { floor: "high" };
      if (level === "trivial") return { floor: "low", ceiling: "low" };
      return { floor: task === "chat" ? "low" : "medium", ceiling: "medium" };
    case "reasoning":
      // Planning, trade-offs, root-cause analysis: thinking *is* the work.
      if (level === "complex") return { floor: "xhigh" };
      if (level === "trivial") return { floor: "medium", ceiling: "medium" };
      return { floor: "high" };
    default: {
      // coding — the agentic norm. Trivial edits are mechanical; standard work
      // keeps the session default; complex work gets the xhigh floor.
      if (level === "complex") return { floor: "xhigh" };
      if (level === "trivial") return { floor: "low", ceiling: "low" };
      return { ceiling: "high" };
    }
  }
}

/**
 * Keep a branch on the model it started with unless the affinity changed, so a
 * stable session pays no cache misses:
 *   - text ↔ tool turns flip model, because that is exactly when the right model
 *     changes (deepseek for text, muse/luna for tools)
 *   - escalate up when a turn turns out harder
 *   - step gpt6 → muse once a plan becomes edits
 *   - never silently downgrade otherwise
 * RANK is the capability ladder for *tool-capable* models; deepseek is handled
 * explicitly because it is specialized, not weak.
 */
export function reconcile(previous: TargetId, next: TargetId, signals: RouteSignals): TargetId {
  if (previous === next) return next;
  if (signals.vision) return GLM_FLASH;
  // deepseek is only for text turns; if that stopped being true, move off it.
  if (previous === DEEPSEEK) return next;
  // A pure text turn mid-branch: deepseek's affinity (math, Q&A, 384k output)
  // is worth the one cache miss, and the next tool turn moves off it again.
  if (next === DEEPSEEK) return DEEPSEEK;
  // plan → implement: stop paying for the reasoner once edits are flowing.
  if (signals.edits && previous === MIMO_PRO) return MUSE;
  // Escalate for a harder turn; never silently downgrade mid-branch.
  if (RANK[next] > RANK[previous]) return next;
  return previous;
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

async function classifyWithJev(req: Req, ctx: ExtensionContext): Promise<{ target: TargetId; effort: { floor?: ThinkingLevel; ceiling?: ThinkingLevel }; complexity: string; taskKind: string; probs: Record<string, number>; signals: RouteSignals } | null> {
  const raw = lastUserText(req.messages);
  const prompt = raw.slice(0, 16_000);
  const classified = await classifyText(prompt, ctx, req.signal);
  if (!classified) return null;
  const signals = readSignals(req.messages, raw);
  return {
    ...classified,
    target: pickTarget(classified.taskKind, classified.probs, signals),
    // Type × complexity, with structural evidence able to force the xhigh floor.
    effort: effortBand(classified.taskKind, classified.complexity, classified.probs, signals),
    signals,
  };
}

// Map Jev answers → compaction summarizer. Unlike live routing, summary output
// is short and bounded, so input price dominates and muse (cheapest everywhere)
// is the default; Jev only promotes histories that need better reasoning.
export function pickSummarizer(complexity: string, taskKind: string): TargetId {
  if (complexity.toLowerCase() === "complex") return MIMO_PRO;
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

const TRIAGE_SECTION = "jev-triage";
const TRIAGE_STATUS_KEY = "jev-triage";

type TriageRole = "scout" | "researcher" | "worker" | "reviewer" | "oracle";

const TRIAGE_GUIDANCE: Record<TriageRole, string> = {
  scout: "Delegation authorized for this run: dispatch recon with the subagent tool — subagent({ agent: \"scout\", task: \"<bounded recon objective + expected report>\" }) — then implement from its findings. If it proves single-file, do it directly.",
  researcher: "Delegation authorized for this run: delegate the investigation with the subagent tool — subagent({ agent: \"researcher\", task: \"<questions + expected synthesis>\", async: true }) — then synthesize the findings. If it's answerable from visible context, answer directly.",
  worker: "Delegation authorized for this run: hand the work package to the subagent tool — subagent({ agent: \"worker\", task: \"<bounded objective + acceptance criteria>\", async: true }) — while you hold the plan. If it proves single-file, do it directly.",
  reviewer: "Delegation authorized for this run: after implementing, have the change verified with the subagent tool — subagent({ agent: \"reviewer\", task: \"<what to verify>\" }).",
  oracle: "Delegation authorized for this run: consult a second opinion before implementing with the subagent tool — subagent({ agent: \"oracle\", task: \"<decision + options considered>\" }).",
};

async function classifyTriage(
  prompt: string,
  ctx: ExtensionContext,
): Promise<{ scope: string; action: string; actionP: number } | null> {
  const jev = ctx.modelRegistry.findOfType("classifier", "typesafe", "jev-latest");
  if (!jev) return null;
  if (!prompt.trim()) return null;

  const result = await ctx.modelRegistry.classify(
    jev,
    {
      state: { prompt },
      questions: {
        scope: {
          type: "choice",
          instructions: "How wide is the work described in `prompt`?",
          criteria: {
            focused: "Single file, single lookup, or a question about already-visible code",
            multi: "Several files but one thread of work",
            broad: "Repo-wide exploration, many unknowns, or parallel lines of inquiry",
          },
        },
        action: {
          type: "choice",
          instructions: "What shape of work does `prompt` ask for?",
          criteria: {
            answer: "Q&A, explanation, or review of visible code — answerable inline",
            explore: "Reconnaissance across the codebase before acting",
            implement: "Multi-step code changes across files",
            review: "A change wanting verification or a second opinion",
          },
        },
      },
    },
    {},
  );

  if (result.stopReason !== "stop") return null;
  const sAns = result.answers.scope;
  const aAns = result.answers.action;
  if (sAns?.type !== "choice" || aAns?.type !== "choice") return null;

  let scope = "focused";
  let maxP = -1;
  for (const [k, v] of Object.entries(sAns.probabilities)) {
    if ((v ?? 0) > maxP) {
      maxP = v ?? 0;
      scope = k;
    }
  }
  let action = "answer";
  let actionP = -1;
  for (const [k, v] of Object.entries(aAns.probabilities)) {
    if ((v ?? 0) > actionP) {
      actionP = v ?? 0;
      action = k;
    }
  }

  return { scope, action, actionP };
}

// Suggest-only verdict. Anything focused/answerable-inline stays silent (null)
// so subagents only enter the picture when the shape of the work earns it.
function triageVerdict(scope: string, action: string, actionP: number): TriageRole | null {
  if (actionP < 0.6) return null;
  switch (action) {
    case "answer":
      return scope === "focused" ? null : "researcher";
    case "explore":
      return "scout";
    case "implement":
      return scope === "focused" ? null : "worker";
    case "review":
      if (scope === "focused") return null;
      return scope === "broad" ? "oracle" : "reviewer";
    default:
      return null;
  }
}

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
        const id = (rawId === LEGACY_MIMO ? MUSE : rawId) as TargetId;
        const known: TargetId[] = [MUSE, MIMO_PRO, DEEPSEEK, GLM_FLASH];
        if (sticky.model.provider === PROVIDER && known.includes(id)) {
          return routeTo(req, ctx, id, req.state);
        }
      }

      // Legacy state migration for branches resumed with an old target.
      const prevTarget: TargetId | undefined = req.state?.target
        ? ((req.state.target as string) === LEGACY_MIMO ? MUSE : req.state.target)
        : undefined;

      // Re-read the conversation on every *user* turn rather than freezing the
      // first verdict for the whole branch: a session that starts as chat and
      // turns into debugging should escalate, and one that starts as planning
      // should drop to the cheap workhorse once edits are flowing. `reconcile`
      // keeps the previous model unless the evidence justifies a switch, so a
      // stable session does not pay cache misses for re-classification.
      const classified = await classifyWithJev(req, ctx).catch(() => null);
      if (classified) {
        const target = prevTarget
          ? reconcile(prevTarget, classified.target, classified.signals)
          : classified.target;
        const state: JevRouterState = {
          target,
          complexity: classified.complexity,
          taskKind: classified.taskKind,
          probs: classified.probs,
        };
        // Band clamps the session level: the floor raises hard turns, the
        // ceiling lowers mechanical ones, floor wins on conflict.
        return routeTo(req, ctx, target, state, classified.effort.floor, classified.effort.ceiling);
      }

      // Jev unavailable (or empty prompt): keep the branch's model if it had one.
      if (prevTarget) {
        const state: JevRouterState = {
          target: prevTarget,
          complexity: req.state?.complexity ?? "standard",
          taskKind: req.state?.taskKind ?? "coding",
        };
        return routeTo(req, ctx, prevTarget, state);
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
  // summarizer that fits (complex → mimo-v2.6-pro, reasoning → glm flash,
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

  pi.on("agent_end", async (_event, ctx) => {
    try {
      ctx.ui.setStatus(TRIAGE_STATUS_KEY, undefined);
    } catch {
      // Footer bookkeeping must never break the loop.
    }
    return undefined;
  });

  // Jev triage: suggest-only delegation. Classifies the user prompt by scope +
  // action and, only when a subagent earns its keep, adds a short guidance
  // section naming the role. Focused work stays silent (section deleted so no
  // stale verdict leaks across runs). Never blocks the run.
  //
  // Skipped inside subagent children (PI_SUBAGENT_CHILD=1) and in any session
  // where `subagent` is not an active tool: delegation guidance is inert there
  // (pi-subagents grants nested spawning only explicitly), and the extra Jev
  // classification call would be pure overhead on every child run.
  pi.on("before_agent_start", async (event, ctx) => {
    try {
      if (event.messageType !== "user") return undefined;
      if (process.env.PI_SUBAGENT_CHILD === "1") return undefined;
      if (!event.systemPromptOptions.selectedTools.includes("subagent")) return undefined;
      const triaged = await classifyTriage(event.prompt.slice(0, 16_000), ctx).catch(() => null);
      const role = triaged ? triageVerdict(triaged.scope, triaged.action, triaged.actionP) : null;
      if (!role) {
        delete event.systemPromptOptions.sections[TRIAGE_SECTION];
        return undefined;
      }
      event.systemPromptOptions.sections[TRIAGE_SECTION] = TRIAGE_GUIDANCE[role];
      ctx.ui.notify(`Jev triage: ${role} fits this task — delegation guidance added.`, "info");
      try {
        ctx.ui.setStatus(TRIAGE_STATUS_KEY, role);
      } catch {
        // Footer bookkeeping must never block a run.
      }
    } catch {
      // Triage must never block a run.
    }
    return undefined;
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
