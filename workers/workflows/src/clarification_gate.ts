import type { Env, WorkflowRequest } from './types';
import { synthesizeJson } from './tools';

interface AssessJson {
  confidence: number;
  questions: string[];
  ready_to_proceed: boolean;
}

/**
 * When research or writing should ask clarifying questions before running (research-only,
 * research→writing, or writing-only). Skipped for revise-in-place and when the client sets
 * skip_writer_clarification after the user answers.
 */
export async function assessWriterClarification(
  req: WorkflowRequest,
  env: Env,
): Promise<{ blocked: boolean; confidence: number; questions: string[] }> {
  if (req.skip_writer_clarification === true) {
    return { blocked: false, confidence: 100, questions: [] };
  }

  const wp = req.writing_preferences;
  if (wp != null && wp.task === 'revise_in_place') {
    return { blocked: false, confidence: 100, questions: [] };
  }

  const docNames =
    req.source_documents?.map((d) => (d.name ?? '').trim()).filter(Boolean).join(', ') || 'none';
  const format = wp != null && typeof wp.format === 'string' ? wp.format : 'unspecified';

  const prompt = `You are a brief intake editor for a research and writing assistant (the next step may be web research only, research plus drafting, or writing only).

USER REQUEST (may include pasted context):
${req.input.slice(0, 12_000)}

ATTACHED DOCUMENT FILENAMES (content sent separately to the pipeline): ${docNames}
SELECTED FORMAT TIER (from app): ${format}

Decide if you are ~90%+ sure of: (1) core topic, (2) intended audience, (3) angle or thesis, (4) what a successful deliverable looks like.

Return ONLY valid JSON:
{
  "confidence": <number 0-100, your certainty they gave enough to proceed>,
  "ready_to_proceed": <boolean, true if confidence >= 90 OR the ask is extremely narrow and unambiguous>,
  "questions": <string array, 0-4 short questions; empty if ready_to_proceed>
}

If anything important is ambiguous (e.g. which product line, tone, length, or which attached doc is primary), add concrete questions. No preamble outside JSON.`;

  try {
    const out = await synthesizeJson<AssessJson>(
      prompt,
      'You return only compact JSON. Questions must be specific and easy for a human to answer in one sentence each.',
      env,
    );
    const confidence = Math.max(0, Math.min(100, Number(out.confidence) || 0));
    const questions = (out.questions ?? [])
      .map((q) => (typeof q === 'string' ? q.trim() : ''))
      .filter((q) => q.length > 0)
      .slice(0, 4);
    const ready = out.ready_to_proceed === true || confidence >= 90;
    if (ready || questions.length === 0) {
      return { blocked: false, confidence, questions: [] };
    }
    return { blocked: true, confidence, questions };
  } catch {
    return { blocked: false, confidence: 85, questions: [] };
  }
}
