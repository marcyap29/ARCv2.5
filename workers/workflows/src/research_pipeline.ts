import type { Env, WorkflowRequest } from './types';
import { braveSearch, groqExtract, jinaFetch, synthesize, synthesizeJson } from './tools';

interface PlanJson {
  questions: string[];
}

interface ExtractedItem {
  question: string;
  source: string;
  url: string;
  keyPoints: string;
}

function sourceDocumentsBlock(req: WorkflowRequest): string {
  const docs = req.source_documents;
  if (docs == null || docs.length === 0) return '';
  const parts: string[] = [];
  for (const d of docs) {
    const name = (d.name ?? 'document').trim() || 'document';
    const text = (d.text ?? '').trim();
    if (text === '') continue;
    const cap = 14_000;
    parts.push(`### ${name}\n${text.length > cap ? `${text.slice(0, cap)}…` : text}`);
  }
  if (parts.length === 0) return '';
  return `\n\nUSER-UPLOADED SOURCE DOCUMENTS (treat as authoritative when they cover the topic):\n${parts.join('\n\n')}\n`;
}

/**
 * Plans exactly four sub-questions for web + academic-style search (used before search, and
 * optionally surfaced to the user for confirmation via clarification_needed).
 */
export async function planResearchSubQuestions(
  req: WorkflowRequest,
  env: Env,
): Promise<string[]> {
  const docBlock = sourceDocumentsBlock(req);

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
        ${docBlock}

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
  return questions.slice(0, 4);
}

/**
 * Runs web research + synthesis. Emits progress via [onProgress].
 * Merges optional uploaded documents into planning and final report context.
 */
export async function runResearchPipeline(
  req: WorkflowRequest,
  env: Env,
  onProgress: (message: string) => void,
): Promise<{
  report: string;
  sources: { title: string; url: string }[];
}> {
  const docBlock = sourceDocumentsBlock(req);

  onProgress('Planning sub-questions...');

  const questions = await planResearchSubQuestions(req, env);

  onProgress(`${questions.length} sub-questions planned`);
  onProgress('Searching web and academic sources...');

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

  onProgress(`${uniqueEntries.length} sources found`);
  onProgress('Reading sources...');

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

  onProgress('Extracting key insights...');
  onProgress('Synthesizing report...');

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

        ${docBlock}
        WEB RESEARCH FINDINGS:
        ${findingsBlock}

        Structure as:
        # ${req.input}
        ## Executive Summary
        ## Key Findings
        ## Implications
        ## Gaps & Open Questions
        ## Sources

        Be specific and analytical. When user documents conflict with the web, prefer the user's documents for their product or internal concepts.
        Use actual data points from the findings and documents.`,
    system,
    env,
  );

  return {
    report,
    sources: extractedItems.map((e) => ({ title: e.source, url: e.url })),
  };
}
