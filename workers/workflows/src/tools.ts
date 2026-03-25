import type { Env, SearchResult } from './types';

export async function braveSearch(
  query: string,
  env: Env,
  count = 5,
): Promise<SearchResult[]> {
  try {
    const u = new URL('https://api.search.brave.com/res/v1/web/search');
    u.searchParams.set('q', query);
    u.searchParams.set('count', String(count));
    const res = await fetch(u.toString(), {
      headers: {
        Accept: 'application/json',
        'X-Subscription-Token': env.BRAVE_API_KEY,
      },
    });
    if (!res.ok) return [];
    const data = (await res.json()) as {
      web?: { results?: { title?: string; url?: string; description?: string }[] };
    };
    const results = data.web?.results ?? [];
    return results
      .filter((r) => r.url)
      .map((r) => ({
        title: r.title ?? '',
        url: r.url as string,
        description: r.description ?? '',
      }));
  } catch {
    return [];
  }
}

export async function jinaFetch(url: string, env: Env, charLimit = 8000): Promise<string> {
  const base = env.JINA_BASE_URL.replace(/\/$/, '');
  const target = url.startsWith('http') ? url : `https://${url}`;
  const jinaUrl = `${base}/${target}`;
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 15_000);
  try {
    const res = await fetch(jinaUrl, {
      headers: {
        Accept: 'text/plain',
        'X-Return-Format': 'text',
      },
      signal: ac.signal,
    });
    const text = await res.text();
    const trimmed = text.trim();
    return trimmed.length > charLimit ? trimmed.slice(0, charLimit) : trimmed;
  } catch {
    return `[fetch failed: ${url}]`;
  } finally {
    clearTimeout(t);
  }
}

async function groqChat(
  system: string,
  user: string,
  env: Env,
  options: {
    smart: boolean;
    maxTokens: number;
    temperature: number;
    jsonObject?: boolean;
  },
): Promise<string> {
  const model = options.smart ? env.GROQ_SMART_MODEL : env.GROQ_FAST_MODEL;
  const body: Record<string, unknown> = {
    model,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    max_tokens: options.maxTokens,
    temperature: options.temperature,
  };
  if (options.jsonObject) {
    body.response_format = { type: 'json_object' };
  }
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.GROQ_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`Groq HTTP ${res.status}`);
  }
  const data = (await res.json()) as {
    choices?: { message?: { content?: string } }[];
  };
  const content = data.choices?.[0]?.message?.content;
  if (content == null || content === '') {
    throw new Error('Groq empty response');
  }
  return content;
}

export async function groqExtract(
  text: string,
  instruction: string,
  env: Env,
  smart = false,
): Promise<string> {
  return groqChat(instruction, text.slice(0, 6000), env, {
    smart,
    maxTokens: 1200,
    temperature: 0.2,
  });
}

export async function groqJson<T>(
  text: string,
  instruction: string,
  env: Env,
  smart = false,
): Promise<T> {
  const raw = await groqChat(instruction, text.slice(0, 6000), env, {
    smart,
    maxTokens: 2000,
    temperature: 0.2,
    jsonObject: true,
  });
  return JSON.parse(stripJsonFences(raw)) as T;
}

function geminiTextFromResponse(data: unknown): string {
  const d = data as {
    candidates?: {
      content?: { parts?: { text?: string }[] };
    }[];
  };
  const parts = d.candidates?.[0]?.content?.parts;
  const t = parts?.map((p) => p.text ?? '').join('') ?? '';
  if (!t) throw new Error('Gemini empty response');
  return t;
}

export async function geminiSynthesize(
  prompt: string,
  system: string,
  env: Env,
  jsonMode = false,
): Promise<string> {
  const combined = `${system}\n\n${prompt}`;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(env.GEMINI_MODEL)}:generateContent?key=${encodeURIComponent(env.GEMINI_API_KEY)}`;
  const generationConfig: Record<string, unknown> = {
    maxOutputTokens: 4000,
    temperature: jsonMode ? 0.1 : 0.7,
  };
  if (jsonMode) {
    generationConfig.responseMimeType = 'application/json';
  }
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: combined }] }],
      generationConfig,
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini ${res.status}: ${errText.slice(0, 200)}`);
  }
  const data = await res.json();
  return geminiTextFromResponse(data);
}

export async function groqSynthFallback(
  prompt: string,
  system: string,
  env: Env,
  jsonMode = false,
): Promise<string> {
  const body: Record<string, unknown> = {
    model: env.GROQ_SYNTH_MODEL,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: prompt },
    ],
    max_tokens: 4000,
    temperature: jsonMode ? 0.1 : 0.7,
  };
  if (jsonMode) {
    body.response_format = { type: 'json_object' };
  }
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.GROQ_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`Groq synth HTTP ${res.status}`);
  }
  const data = (await res.json()) as {
    choices?: { message?: { content?: string } }[];
  };
  const content = data.choices?.[0]?.message?.content;
  if (content == null || content === '') {
    throw new Error('Groq synth empty response');
  }
  return content;
}

export async function synthesize(
  prompt: string,
  system: string,
  env: Env,
): Promise<string> {
  try {
    return await geminiSynthesize(prompt, system, env, false);
  } catch {
    return groqSynthFallback(prompt, system, env, false);
  }
}

function stripJsonFences(s: string): string {
  let t = s.trim();
  if (t.startsWith('```')) {
    t = t.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/u, '');
  }
  return t.trim();
}

export async function synthesizeJson<T>(
  prompt: string,
  system: string,
  env: Env,
): Promise<T> {
  try {
    const raw = await geminiSynthesize(prompt, system, env, true);
    return JSON.parse(stripJsonFences(raw)) as T;
  } catch {
    const raw = await groqSynthFallback(prompt, system, env, true);
    return JSON.parse(stripJsonFences(raw)) as T;
  }
}
