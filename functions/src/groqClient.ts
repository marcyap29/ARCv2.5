// groqClient.ts - Groq API client for LUMARA functions
// Uses Groq OpenAI-compatible API (GPT-OSS 120B / Llama 3.3 70B)

import https from "https";

const GROQ_API_HOST = "api.groq.com";
const GROQ_PATH = "/openai/v1/chat/completions";
const DEFAULT_MODEL = "openai/gpt-oss-120b";
const REQUEST_TIMEOUT_MS = 85000;

export type ChatMessage = { role: "user" | "assistant"; content: string };

/** Call Groq OpenAI-compatible API (non-streaming) */
export async function groqChatCompletion(
  apiKey: string,
  options: {
    system?: string;
    user: string;
    conversationHistory?: ChatMessage[];
    model?: string;
    temperature?: number;
    maxTokens?: number;
  }
): Promise<string> {
  const {
    system = "",
    user,
    conversationHistory = [],
    model = DEFAULT_MODEL,
    temperature = 0.7,
    maxTokens = 8192,
  } = options;

  const messages: Array<{ role: string; content: string }> = [];
  if (system.trim().length > 0) {
    messages.push({ role: "system", content: system });
  }
  for (const m of conversationHistory) {
    messages.push({ role: m.role, content: m.content });
  }
  messages.push({ role: "user", content: user });

  const body = JSON.stringify({
    model,
    messages,
    temperature,
    max_tokens: maxTokens,
    stream: false,
  });

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: GROQ_API_HOST,
        path: GROQ_PATH,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        let buf = "";
        res.on("data", (chunk) => {
          buf += chunk;
        });
        res.on("end", () => {
          if (res.statusCode !== 200) {
            reject(new Error(`Groq API error: ${res.statusCode} - ${buf}`));
            return;
          }
          try {
            const parsed = JSON.parse(buf);
            const content = parsed.choices?.[0]?.message?.content;
            if (content == null) {
              reject(new Error("Groq API returned no content"));
            } else {
              resolve(content);
            }
          } catch (e) {
            reject(new Error("Invalid Groq response: " + buf));
          }
        });
      }
    );
    req.on("error", reject);
    req.setTimeout(REQUEST_TIMEOUT_MS, () => {
      req.destroy();
      reject(new Error("Groq API request timed out"));
    });
    req.write(body);
    req.end();
  });
}
