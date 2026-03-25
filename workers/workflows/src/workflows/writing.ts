import type { Env, SSEMessage, WorkflowRequest } from '../types';
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

export async function handleWriting(
  req: WorkflowRequest,
  env: Env,
  send: (msg: SSEMessage) => void,
): Promise<void> {
  send({
    type: 'step_start',
    step: 'Writing',
    message: 'Extracting core narrative...',
  });

  const voice =
    req.chronicle_context != null
      ? `Voice and context: ${req.chronicle_context.recent}`
      : '';

  const narrative = await synthesizeJson<NarrativeJson>(
    `From this input, extract the core narrative for content.
        Input: ${req.input}
        ${voice}

        Return JSON with: headline, core_insight, target_pain, cta`,
    'You are a content strategist. Extract what is genuinely interesting.',
    env,
  );

  send({ type: 'progress', message: 'Narrative extracted' });

  send({ type: 'progress', message: 'Writing for each platform...' });

  const requestedPlatforms: string[] =
    (req as any).platforms?.length > 0
      ? (req as any).platforms
      : ['linkedin', 'orbital_ai', 'mechanical_musings'];
  const results: Record<string, string> = {};

  for (const platformId of requestedPlatforms) {
    const spec = PLATFORM_SPECS[platformId];
    if (!spec) continue;

    send({ type: 'progress', message: `Writing ${spec.label}...` });

    results[platformId] = await synthesize(
      `Write a ${spec.desc} based on this narrative:
       Headline: ${narrative.headline}
       Core insight: ${narrative.core_insight}
       Pain addressed: ${narrative.target_pain}
       CTA: ${narrative.cta}
       ${
         req.chronicle_context && req.use_chronicle
           ? `Write in the voice of: ${req.chronicle_context.profile}.
            Voice reference: ${req.chronicle_context.recent}`
           : ''
       }
       
       Tone: ${spec.tone}
       Format: ${spec.format}
       Target length: ${spec.length}
       
       Do not use em dashes.
       Do not start with "I" or with the product name.
       Do not use: game-changer, revolutionary, unleash, harness, dive in.`,
      `You are writing authentic content for ${spec.desc}.`,
      env,
    );
  }

  send({
    type: 'step_complete',
    step: 'Writing',
    message: 'Content ready',
  });
  send({
    type: 'result',
    data: {
      narrative,
      platforms: results,
      generated_platforms: requestedPlatforms.filter((p) => results[p]),
      platform_labels: Object.fromEntries(
        requestedPlatforms
          .filter((p) => PLATFORM_SPECS[p])
          .map((p) => [p, PLATFORM_SPECS[p].label]),
      ),
    },
  });
}
