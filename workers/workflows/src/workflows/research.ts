import type { Env, SSEMessage, WorkflowRequest } from '../types';
import { braveSearch, groqExtract, jinaFetch, synthesize, synthesizeJson } from '../tools';

interface PlanJson {
  questions: string[];
}

interface ExtractedItem {
  question: string;
  source: string;
  url: string;
  keyPoints: string;
}

export async function handleResearch(
  req: WorkflowRequest,
  env: Env,
  send: (msg: SSEMessage) => void,
): Promise<void> {
  send({
    type: 'step_start',
    step: 'Research',
    message: 'Planning sub-questions...',
  });

  const ctxBlock =
    req.chronicle_context != null
      ? `User context: ${req.chronicle_context.profile}.
        Recent: ${req.chronicle_context.recent}`
      : '';

  const plan = await synthesizeJson<PlanJson>(
    `Break this research query into exactly 4 focused sub-questions that together
        fully answer the query from different angles.

        Query: ${req.input}
        ${ctxBlock}

        Return JSON: { "questions": ["q1", "q2", "q3", "q4"] }`,
    'You are a research strategist. Return only valid JSON.',
    env,
  );

  let questions = (plan.questions ?? []).filter((q) => q.trim() !== '').slice(0, 4);
  if (questions.length === 0) {
    questions = [req.input];
  }
  while (questions.length < 4) {
    questions.push(req.input);
  }
  questions = questions.slice(0, 4);

  send({
    type: 'progress',
    message: `${questions.length} sub-questions planned`,
  });

  send({
    type: 'progress',
    message: 'Searching web and academic sources...',
  });

  type UrlEntry = { url: string; title: string; question: string };
  const byUrl = new Map<string, UrlEntry>();

  for (const q of questions) {
    const webResults = await braveSearch(q, env, 4);
    let taken = 0;
    for (const r of webResults) {
      if (taken >= 2) break;
      if (!byUrl.has(r.url)) {
        byUrl.set(r.url, { url: r.url, title: r.title || r.url, question: q });
        taken += 1;
      }
    }
  }

  const uniqueEntries = [...byUrl.values()].slice(0, 8);

  send({
    type: 'progress',
    message: `${uniqueEntries.length} sources found`,
  });

  send({ type: 'progress', message: 'Reading sources...' });

  const extractedItems: ExtractedItem[] = [];

  for (const entry of uniqueEntries) {
    const content = await jinaFetch(entry.url, env);
    const keyPoints = await groqExtract(
      content,
      `Extract 3-5 specific facts or insights relevant to: "${entry.question}".
          Each point on its own line starting with •`,
      env,
    );
    extractedItems.push({
      question: entry.question,
      source: entry.title,
      url: entry.url,
      keyPoints,
    });
  }

  send({ type: 'progress', message: 'Extracting key insights...' });

  send({ type: 'progress', message: 'Synthesizing report...' });

  const findingsBlock = extractedItems
    .map(
      (e) =>
        `### ${e.source} (${e.url})\nQuestion angle: ${e.question}\n${e.keyPoints}\n`,
    )
    .join('\n');

  const system =
    req.chronicle_context != null && req.use_chronicle === true
      ? `You are an expert research analyst writing for ${req.chronicle_context.profile}.
          Calibrate depth and vocabulary to their background.
          Their recent context: ${req.chronicle_context.recent}`
      : 'You are an expert research analyst. Be specific, concise, and data-driven.';

  const report = await synthesize(
    `Write a comprehensive research report on: ${req.input}

        RESEARCH FINDINGS:
        ${findingsBlock}

        Structure as:
        # ${req.input}
        ## Executive Summary
        ## Key Findings
        ## Implications
        ## Gaps & Open Questions
        ## Sources

        Be specific and analytical. Use actual data points from the findings.`,
    system,
    env,
  );

  send({
    type: 'step_complete',
    step: 'Research',
    message: 'Report complete',
  });
  send({
    type: 'result',
    data: {
      report,
      sources: extractedItems.map((e) => ({ title: e.source, url: e.url })),
    },
  });
}
