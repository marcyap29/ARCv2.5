import type { ChronicleBundle, Env, SSEMessage, WorkflowRequest } from '../types';
import { assessWriterClarification } from '../clarification_gate';
import { synthesize, synthesizeJson } from '../tools';

const PLATFORM_SPECS: Record<
  string,
  {
    id: string;
    label: string;
    desc: string;
    tone: string;
    format: string;
    length: string;
  }
> = {
  linkedin: {
    id: 'linkedin',
    label: 'LinkedIn',
    desc: 'LinkedIn post for founders, operators, and builders',
    tone: 'authoritative but approachable, first person, no corporate speak, no em dashes',
    format: 'strong hook line, 3-4 paragraph body, 3-5 relevant hashtags at end',
    length: '200-280 words',
  },
  orbital_ai: {
    id: 'orbital_ai',
    label: 'Orbital AI (Substack)',
    desc: 'Orbital AI Substack post — product-focused technical blog for builders and early adopters following AI infrastructure',
    tone: 'founder building in public, technically credible, direct, no hype',
    format:
      'headline, 1-paragraph hook, 3-4 substantive sections with subheadings, conclusion with what comes next',
    length: '500-700 words',
  },
  mechanical_musings: {
    id: 'mechanical_musings',
    label: 'Mechanical Musings (Substack)',
    desc: 'Mechanical Musings personal Substack — personal takes on AI from someone with aerospace and defense background',
    tone: 'personal, opinionated, intellectually curious, draws on systems thinking and engineering perspective, not a product pitch',
    format:
      'personal observation or question as hook, essay-style exploration, ends with an open question or provocation',
    length: '500-700 words',
  },
  twitter: {
    id: 'twitter',
    label: 'Twitter / X',
    desc: 'Twitter/X thread for the tech and builder community',
    tone: 'punchy, direct, no filler, slightly irreverent',
    format:
      '6-8 tweets numbered 1/ 2/ etc, each strictly under 280 chars, first tweet works as standalone',
    length: '6-8 tweets',
  },
  bluesky: {
    id: 'bluesky',
    label: 'Bluesky',
    desc: 'Bluesky thread — similar to Twitter but slightly more technical and thoughtful audience',
    tone: 'direct, technical, intellectually honest',
    format: '5-7 posts numbered 1/ 2/ etc, each under 300 chars',
    length: '5-7 posts',
  },
  reddit: {
    id: 'reddit',
    label: 'Reddit',
    desc: 'Reddit post for r/mcp, r/LocalLLaMA, or r/ArtificialIntelligence',
    tone: 'community member sharing something genuinely useful, not promotional, show the work',
    format: 'title + body 300-450 words, no hard sell, ends with a question for community',
    length: '300-450 words',
  },
  devto: {
    id: 'devto',
    label: 'Dev.to',
    desc: 'Dev.to article for developers — practical, tutorial-adjacent',
    tone: 'practical, slightly informal, developer peer',
    format: 'headline, lede paragraph, 3-bullet what you will learn, first section opener',
    length: '250-350 words (article intro only)',
  },
  hacker_news: {
    id: 'hacker_news',
    label: 'Hacker News',
    desc: 'Hacker News Show HN or Ask HN post',
    tone: 'technical, humble, specific about what was built and why',
    format: 'title line + 150-200 word explanation, no marketing language',
    length: '150-200 words',
  },
};

interface NarrativeJson {
  headline: string;
  core_insight: string;
  target_pain: string;
  cta: string;
}

export interface WritingCoreResult {
  narrative: NarrativeJson;
  platforms: Record<string, string>;
  generated_platforms: string[];
  platform_labels: Record<string, string>;
}

export type WritingExecutionOutcome =
  | { status: 'clarification_needed'; confidence: number; questions: string[] }
  | { status: 'complete'; data: WritingCoreResult };

function formatInstructionFromPrefs(wp: Record<string, unknown> | undefined): string {
  if (wp == null) return 'Match each platform spec; follow the user request.';
  const f = wp.format as string | undefined;
  switch (f) {
    case 'short_threads':
      return 'SMALL / short-form: punchy social (Twitter/X, Bluesky, Reddit). Hooks first; minimal throat-clearing.';
    case 'medium_social':
      return 'MEDIUM: LinkedIn / Reddit depth — professional, concrete, still scannable.';
    case 'large_substack':
      return 'LARGE: Substack-style essay — sections, narrative arc, technical clarity where appropriate.';
    case 'xl_white_paper':
    case 'research_paper':
      return 'XL: white paper / research rigor — structure, definitions, careful claims, minimal hype.';
    case 'article':
      return 'ARTICLE: general long-form article — thesis, sections, readable depth (not thread-length).';
    default:
      return 'Match each platform spec; follow the user request.';
  }
}

function chronicleSemanticBlock(ctx: ChronicleBundle | undefined): string {
  if (ctx == null) return '';
  const hits = ctx.semantic_hits;
  if (hits == null || hits.length === 0) return '';
  const lines = hits
    .map(
      (h, i) =>
        `${i + 1}. [score ${h.score != null ? h.score.toFixed(3) : 'n/a'}] (${h.entry_date ?? 'date unknown'}) ${h.snippet}`,
    )
    .join('\n');
  const note = ctx.integration_note?.trim() ?? '';
  return `\n\nCHRONICLE SEMANTIC / KEYWORD MATCHES (from the user's journal — confirm relevance; do not fabricate private facts):\n${lines}\n${note ? `\nIntegration guidance: ${note}\n` : ''}`;
}

/**
 * Shared narrative + multi-platform generation. Used by writing-only and research→writing flows.
 * Runs an optional clarification gate unless [options.skipWriterClarification] is true.
 */
export async function executeWritingCore(
  req: WorkflowRequest,
  env: Env,
  onProgress: (message: string) => void,
  options?: { priorResearchReport?: string; skipWriterClarification?: boolean },
): Promise<WritingExecutionOutcome> {
  if (options?.skipWriterClarification !== true) {
    const gate = await assessWriterClarification(req, env);
    if (gate.blocked && gate.questions.length > 0) {
      return {
        status: 'clarification_needed',
        confidence: gate.confidence,
        questions: gate.questions,
      };
    }
  }

  const semantic = chronicleSemanticBlock(req.chronicle_context);
  const formatHint = formatInstructionFromPrefs(req.writing_preferences);
  const research = options?.priorResearchReport?.trim() ?? '';
  const researchBlock =
    research.length > 0
      ? `\n\nPRIOR RESEARCH REPORT (use facts, product names, and themes from here):\n${research.slice(0, 18_000)}${research.length > 18_000 ? '…' : ''}\n`
      : '';

  const voice =
    req.chronicle_context != null
      ? `Voice and context: ${req.chronicle_context.recent}`
      : '';

  onProgress('Extracting core narrative...');

  const narrative = await synthesizeJson<NarrativeJson>(
    `From this input, extract the core narrative for content.
        User request / input: ${req.input}
        ${researchBlock}
        ${voice}
        ${semantic}

        FORMAT / LENGTH INTENT (from user settings):
        ${formatHint}

        If CHRONICLE semantic matches are present, only incorporate them when they clearly relate to the topic; never invent private diary details not implied by the snippets.

        Return JSON with: headline, core_insight, target_pain, cta`,
    'You are a content strategist. Extract what is genuinely interesting. Stay faithful to the research report and user documents when provided.',
    env,
  );

  onProgress('Narrative extracted');
  onProgress('Writing for each platform...');

  const requestedPlatforms: string[] =
    req.platforms != null && req.platforms.length > 0
      ? req.platforms
      : ['linkedin', 'orbital_ai', 'mechanical_musings'];
  const results: Record<string, string> = {};

  const chronicleVoice =
    req.chronicle_context != null && req.use_chronicle
      ? `Write in the voice of: ${req.chronicle_context.profile}.
            Voice reference: ${req.chronicle_context.recent}`
      : '';

  const researchTail = research.length > 0 ? research.slice(0, 8000) : '';

  for (const platformId of requestedPlatforms) {
    const spec = PLATFORM_SPECS[platformId];
    if (!spec) continue;

    onProgress(`Writing ${spec.label}...`);

    results[platformId] = await synthesize(
      `Write a ${spec.desc} based on this narrative:
       Headline: ${narrative.headline}
       Core insight: ${narrative.core_insight}
       Pain addressed: ${narrative.target_pain}
       CTA: ${narrative.cta}
       ${chronicleVoice ? `${chronicleVoice}\n` : ''}
       ${researchTail ? `Ground details in this research excerpt where relevant:\n${researchTail}\n` : ''}

       Tone: ${spec.tone}
       Format: ${spec.format}
       Target length: ${spec.length}

       User format intent: ${formatHint}

       Do not use em dashes.
       Do not start with "I" or with the product name.
       Do not use: game-changer, revolutionary, unleash, harness, dive in.`,
      `You are writing authentic content for ${spec.desc}.`,
      env,
    );
  }

  return {
    status: 'complete',
    data: {
      narrative,
      platforms: results,
      generated_platforms: requestedPlatforms.filter((p) => results[p]),
      platform_labels: Object.fromEntries(
        requestedPlatforms.filter((p) => PLATFORM_SPECS[p]).map((p) => [p, PLATFORM_SPECS[p].label]),
      ),
    },
  };
}

export async function handleWriting(
  req: WorkflowRequest,
  env: Env,
  send: (msg: SSEMessage) => void,
): Promise<void> {
  send({
    type: 'step_start',
    step: 'Writing',
    message: 'Checking whether clarifications are needed...',
  });

  const outcome = await executeWritingCore(req, env, (message) => {
    send({ type: 'progress', message });
  });

  if (outcome.status === 'clarification_needed') {
    send({
      type: 'clarification_needed',
      step: 'Writing',
      message: 'Please answer the questions in the app, then continue.',
      data: {
        confidence: outcome.confidence,
        questions: outcome.questions,
      },
    });
    return;
  }

  const core = outcome.data;

  send({
    type: 'step_complete',
    step: 'Writing',
    message: 'Content ready',
  });
  send({
    type: 'result',
    data: {
      narrative: core.narrative,
      platforms: core.platforms,
      generated_platforms: core.generated_platforms,
      platform_labels: core.platform_labels,
    },
  });
}
