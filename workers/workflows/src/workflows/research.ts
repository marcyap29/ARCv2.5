import type { Env, SSEMessage, WorkflowRequest } from '../types';
import { assessWriterClarification } from '../clarification_gate';
import { runResearchPipeline } from '../research_pipeline';

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
        confidence: gate.confidence,
        questions: gate.questions,
      },
    });
    return;
  }

  send({
    type: 'step_start',
    step: 'Research',
    message: 'Planning sub-questions...',
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
