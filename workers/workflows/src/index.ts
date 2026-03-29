import type { Env, WorkflowRequest } from './types';
import { createSSEStream } from './sse';
import { handleCompetitor } from './workflows/competitor';
import { handlePlugins } from './workflows/plugins';
import { handleResearch } from './workflows/research';
import { handleWriting } from './workflows/writing';
import { handleResearchWriting } from './workflows/research_writing';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function corsResponse(status: number, text: string): Response {
  return new Response(text, { status, headers: corsHeaders });
}

export default {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return corsResponse(405, 'Method not allowed');
    }

    const url = new URL(request.url);
    const path = url.pathname;

    const validRoutes = [
      '/workflows/research',
      '/workflows/writing',
      '/workflows/research-writing',
      '/workflows/competitor',
      '/workflows/plugins',
    ] as const;

    if (!validRoutes.includes(path as (typeof validRoutes)[number])) {
      return corsResponse(404, 'Not found');
    }

    let body: WorkflowRequest;
    try {
      body = (await request.json()) as WorkflowRequest;
    } catch {
      return corsResponse(400, 'Invalid JSON body');
    }

    if (body.input?.trim() == null || body.input.trim() === '') {
      return corsResponse(400, 'input is required');
    }

    const { send, close, response } = createSSEStream();

    const run = async (): Promise<void> => {
      try {
        if (path === '/workflows/research') {
          await handleResearch(body, env, send);
        } else if (path === '/workflows/research-writing') {
          await handleResearchWriting(body, env, send);
        } else if (path === '/workflows/writing') {
          await handleWriting(body, env, send);
        } else if (path === '/workflows/competitor') {
          await handleCompetitor(body, env, send);
        } else if (path === '/workflows/plugins') {
          await handlePlugins(body, env, send);
        }
      } catch (err) {
        send({ type: 'error', message: String(err) });
      } finally {
        close();
      }
    };

    ctx.waitUntil(run());

    return response;
  },
};
