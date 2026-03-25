import type { CompetitiveCard, Env, SSEMessage, WorkflowRequest } from '../types';
import { braveSearch, groqExtract, jinaFetch, synthesize, synthesizeJson } from '../tools';

export async function handleCompetitor(
  req: WorkflowRequest,
  env: Env,
  send: (msg: SSEMessage) => void,
): Promise<void> {
  send({
    type: 'step_start',
    step: 'Competitor Intel',
    message: 'Scouting sources...',
  });

  const nameResult = await groqExtract(
    req.input,
    'Extract just the competitor or company name being researched. Return only the name, nothing else.',
    env,
  );
  const competitorName = nameResult.trim() || 'competitor';

  const queries = [
    `${competitorName} pricing features 2025 2026`,
    `${competitorName} reviews complaints alternatives`,
    `${competitorName} news launch update 2026`,
    `${competitorName} vs SwarmSpace comparison`,
  ];

  const seen = new Set<string>();
  const urlList: { url: string; title: string }[] = [];

  for (const q of queries) {
    const hits = await braveSearch(q, env, 6);
    for (const h of hits) {
      if (seen.has(h.url)) continue;
      seen.add(h.url);
      urlList.push({ url: h.url, title: h.title || h.url });
      if (urlList.length >= 6) break;
    }
    if (urlList.length >= 6) break;
  }

  send({
    type: 'progress',
    message: `${urlList.length} sources found`,
  });

  send({ type: 'progress', message: 'Extracting competitive signals...' });

  const signalChunks: string[] = [];

  for (const { url, title } of urlList) {
    const content = await jinaFetch(url, env);
    const signals = await groqExtract(
      content,
      `Extract competitive intelligence about '${competitorName}':
          - Pricing (plans, tiers, exact costs)
          - Features and capabilities
          - Target customer
          - Recent product news
          - User complaints or weaknesses
          - How they position themselves
          Be specific. Quote prices and features exactly if present.`,
      env,
      true,
    );
    signalChunks.push(`## ${title}\n${url}\n${signals}`);
  }

  const signalsText = signalChunks.join('\n\n---\n\n');

  send({ type: 'progress', message: 'Building competitive card...' });

  const card = await synthesizeJson<CompetitiveCard>(
    `Build a structured competitive card for '${competitorName}'.

        RESEARCH:
        ${signalsText}

        Return JSON:
        {
          "name": "${competitorName}",
          "tagline": "their positioning in one sentence",
          "pricing": { "model": "freemium|paid|credits|enterprise", "tiers": [], "notes": "" },
          "core_features": ["up to 6"],
          "target_customer": "",
          "strengths": ["3 items"],
          "weaknesses": ["3 items"],
          "recent_moves": ["2 items"],
          "threat_level": "low|medium|high",
          "threat_rationale": "one sentence"
        }
        Use null for missing data. Do not invent.`,
    'You are a competitive intelligence analyst. Return only valid JSON.',
    env,
  );

  send({ type: 'progress', message: 'Writing strategic brief...' });

  const brief = await synthesize(
    `Write a strategic brief on '${competitorName}' for the SwarmSpace team.

        COMPETITIVE CARD:
        ${JSON.stringify(card, null, 2)}

        Structure:
        ## ${competitorName} — Competitive Brief
        ### What They Are
        ### Where They're Strong
        ### Where They're Weak
        ### Positioning Angle for SwarmSpace
        ### Watch List (next 90 days)

        Be direct. A founder is reading this, not a consultant.`,
    'You are a sharp competitive strategist.',
    env,
  );

  send({
    type: 'step_complete',
    step: 'Competitor Intel',
    message: 'Brief ready',
  });
  send({
    type: 'result',
    data: { card, brief },
  });
}
