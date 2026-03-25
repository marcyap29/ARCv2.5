import type { ApiAnalysis, Env, ScoredCandidate, SSEMessage, WorkflowRequest } from '../types';
import { braveSearch, groqJson, jinaFetch, synthesizeJson } from '../tools';

const SKIP_HOST_SUBSTR = ['medium.com', 'reddit.com', 'stackoverflow', 'youtube.com', 'youtu.be'];

function shouldSkipUrl(url: string): boolean {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return SKIP_HOST_SUBSTR.some((s) => host.includes(s));
  } catch {
    return true;
  }
}

function normalizeScored(raw: unknown): ScoredCandidate[] {
  if (Array.isArray(raw)) {
    return raw as ScoredCandidate[];
  }
  if (raw != null && typeof raw === 'object') {
    const o = raw as Record<string, unknown>;
    for (const k of ['items', 'candidates', 'scores', 'results']) {
      const v = o[k];
      if (Array.isArray(v)) {
        return v as ScoredCandidate[];
      }
    }
  }
  return [];
}

function findAnalysisForRecommendation(
  analyses: ApiAnalysis[],
  rec: ScoredCandidate,
): ApiAnalysis | undefined {
  const r = rec.api_name?.toLowerCase() ?? '';
  if (r.length === 0) return undefined;
  return analyses.find((a) => {
    const n = a.api_name?.toLowerCase() ?? '';
    if (n.length === 0) return false;
    return n.includes(r) || r.includes(n);
  });
}

function recommendedDedupeKey(apiName: string | undefined): string {
  return (apiName ?? '')
    .toLowerCase()
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .join(' ');
}

export async function handlePlugins(
  req: WorkflowRequest,
  env: Env,
  send: (msg: SSEMessage) => void,
): Promise<void> {
  send({
    type: 'step_start',
    step: 'Plugin Discovery',
    message: 'Searching for API candidates...',
  });

  const searchQueries = [
    `${req.input} API free tier developer 2025 2026`,
    `best ${req.input} API open source alternatives`,
    `${req.input} REST API documentation pricing`,
  ];

  const seen = new Set<string>();
  const candidates: { url: string; title: string }[] = [];

  for (const q of searchQueries) {
    const hits = await braveSearch(q, env, 8);
    for (const h of hits) {
      if (shouldSkipUrl(h.url)) continue;
      if (seen.has(h.url)) continue;
      seen.add(h.url);
      candidates.push({ url: h.url, title: h.title || h.url });
      if (candidates.length >= 5) break;
    }
    if (candidates.length >= 5) break;
  }

  send({
    type: 'progress',
    message: `${candidates.length} candidates found`,
  });

  send({ type: 'progress', message: 'Analysing candidates...' });

  const analyses: ApiAnalysis[] = [];

  for (const candidate of candidates) {
    const content = await jinaFetch(candidate.url, env);
    const analysis = await groqJson<ApiAnalysis>(
      content,
      `Analyse this API for an AI agent plugin marketplace.
          Return JSON:
          {
            "api_name": "",
            "provider": "",
            "what_it_does": "one sentence",
            "free_tier": "describe or null",
            "paid_pricing": "describe or null",
            "auth_method": "none|api_key|oauth|unknown",
            "rate_limits": "describe or null",
            "latency_class": "fast|standard|slow|unknown",
            "data_sent_to_api": "what user data is transmitted",
            "suitable_for_ai_agents": true or false,
            "concern": "privacy/ToS concern or null"
          }`,
      env,
      true,
    );
    analyses.push(analysis);
  }

  send({ type: 'progress', message: 'Scoring and generating manifests...' });

  const scoredRaw = await synthesizeJson<unknown>(
    `Evaluate these APIs for SwarmSpace (consumer AI agent marketplace).

        Good criteria: free tier, agent-suitable, privacy-respectable, reliable, no ToS issues.

        CANDIDATES: ${JSON.stringify(analyses, null, 2)}

        Return JSON array:
        [{ "api_name": "", "recommended": true/false,
           "recommended_tier": "free|standard|premium",
           "score_rationale": "one sentence" }]`,
    'You are a technical product manager. Be selective.',
    env,
  );

  const scored = normalizeScored(scoredRaw);
  const recommended = scored.filter((s) => s.recommended);

  const seenRecommendedNames = new Set<string>();
  const uniqueRecommended = recommended.filter((rec) => {
    const key = recommendedDedupeKey(rec.api_name);
    if (key === '') return true;
    if (seenRecommendedNames.has(key)) return false;
    seenRecommendedNames.add(key);
    return true;
  });

  const manifests: unknown[] = [];

  for (const rec of uniqueRecommended) {
    const analysis = findAnalysisForRecommendation(analyses, rec);
    if (analysis == null) {
      const fallbackManifest = await synthesizeJson<Record<string, unknown>>(
        `Generate a SwarmSpace plugin manifest for ${rec.api_name}.

       Known info: ${rec.score_rationale}
       Recommended tier: ${rec.recommended_tier}

       Return JSON with these exact fields:
       name, slug (lowercase-hyphens), description (LLM-parseable),
       version ("1.0.0"), access_tier ("${rec.recommended_tier}"),
       trust_tier ("community"), credit_cost_per_call (0),
       semantic_tags (array), latency_class ("standard"),
       privacy_data_required (array, best guess),
       auth_method (best guess: none|api_key|oauth),
       endpoint_url ("https://api.swarmspace.io/proxy/{slug}"),
       canonical_url ("https://swarmspace.io/plugins/{slug}"),
       agent_guidance (when and how to use — written for an LLM),
       developer_name, developer_url (look up if known),
       data_handling (best guess based on API type)`,
        'You are a SwarmSpace platform architect. Generate precise plugin manifests.',
        env,
      );
      manifests.push(fallbackManifest);
      continue;
    }

    const manifest = await synthesizeJson<Record<string, unknown>>(
      `Generate a complete SwarmSpace plugin manifest.

          API: ${JSON.stringify({ ...analysis, ...rec }, null, 2)}

          Return JSON with these exact fields:
          name, slug (lowercase-hyphens), description (LLM-parseable),
          version ("1.0.0"), access_tier (${rec.recommended_tier}),
          trust_tier ("community"), credit_cost_per_call (0 if free),
          semantic_tags (array), latency_class, privacy_data_required (array),
          auth_method, endpoint_url ("https://api.swarmspace.io/proxy/{slug}"),
          canonical_url ("https://swarmspace.io/plugins/{slug}"),
          agent_guidance (when/how to use — written for an LLM to parse),
          developer_name, developer_url, data_handling`,
      'You are a SwarmSpace platform architect. Generate precise plugin manifests.',
      env,
    );
    manifests.push(manifest);
  }

  send({
    type: 'step_complete',
    step: 'Plugin Discovery',
    message: `${manifests.length} manifests generated (${uniqueRecommended.length} recommended)`,
  });
  send({
    type: 'result',
    data: { manifests, scoring: scored },
  });
}
