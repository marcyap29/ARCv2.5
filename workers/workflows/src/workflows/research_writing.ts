import type { Env, SSEMessage, WorkflowRequest } from '../types';
import { assessWriterClarification } from '../clarification_gate';
import { planResearchSubQuestions, runResearchPipeline } from '../research_pipeline';
import { executeWritingCore } from './writing';

/**
 * True research → writing pipeline: web + documents for research, then platform drafts from the report.
 * Intake clarification runs when ambiguous; research search angles are confirmed before web search.
 */
export async function handleResearchWriting(
  req: WorkflowRequest,
  env: Env,
  send: (msg: SSEMessage) => void,
): Promise<void> {
  const gate = await assessWriterClarification(req, env);
  if (gate.blocked && gate.questions.length > 0) {
    send({
      type: 'clarification_needed',
      step: 'Writing',
      message: 'Please answer the questions in the app, then continue.',
      data: {
        phase: 'intake',
        confidence: gate.confidence,
        questions: gate.questions,
      },
    });
    return;
  }

  if (req.skip_research_scope_clarification !== true) {
    send({
      type: 'step_start',
      step: 'Research',
      message: 'Planning sub-questions...',
    });

    const questions = await planResearchSubQuestions(req, env);

    send({
      type: 'progress',
      message: `${questions.length} sub-questions planned`,
    });

    send({
      type: 'clarification_needed',
      step: 'Research',
      message:
        'Review the planned search angles below. Answer to narrow, redirect, or confirm — then we search the web and sources.',
      data: {
        phase: 'research_scope',
        confidence: 100,
        questions: questions.map((q, i) => `Search angle ${i + 1}: ${q}`),
      },
    });
    return;
  }

  send({
    type: 'step_start',
    step: 'Research',
    message: 'Searching web and academic sources...',
  });

  const { report } = await runResearchPipeline(req, env, (message) => {
    send({ type: 'progress', message });
  });

  send({
    type: 'step_complete',
    step: 'Research',
    message: 'Report complete',
  });

  send({
    type: 'step_start',
    step: 'Writing',
    message: 'Extracting core narrative...',
  });

  const outcome = await executeWritingCore(
    req,
    env,
    (message) => {
      send({ type: 'progress', message });
    },
    { priorResearchReport: report, skipWriterClarification: true },
  );

  if (outcome.status === 'clarification_needed') {
    send({
      type: 'clarification_needed',
      step: 'Writing',
      message: 'Please answer the questions in the app, then continue.',
      data: {
        phase: 'writing',
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
      report,
      narrative: core.narrative,
      platforms: core.platforms,
      generated_platforms: core.generated_platforms,
      platform_labels: core.platform_labels,
    },
  });
}
