import type { Env, SSEMessage, WorkflowRequest } from '../types';
import { assessWriterClarification } from '../clarification_gate';
import { planResearchSubQuestions, runResearchPipeline } from '../research_pipeline';

export async function handleResearch(
  req: WorkflowRequest,
  env: Env,
  send: (msg: SSEMessage) => void,
): Promise<void> {
  const gate = await assessWriterClarification(req, env);
  if (gate.blocked && gate.questions.length > 0) {
    send({
      type: 'clarification_needed',
      step: 'Research',
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

  const { report, sources } = await runResearchPipeline(req, env, (message) => {
    send({ type: 'progress', message });
  });

  send({
    type: 'step_complete',
    step: 'Research',
    message: 'Report complete',
  });
  send({
    type: 'result',
    data: {
      report,
      sources,
    },
  });
}
