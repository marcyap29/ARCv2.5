// llmClients.ts - LLM API clients for Gemini and Claude

import { ModelConfig, ModelFamily } from "./types";

/**
 * Gemini API Client
 * 
 * Supports both Gemini Flash and Gemini Pro
 * Uses the same API endpoint, different model IDs
 */
export class GeminiClient {
  private config: ModelConfig;

  constructor(config: ModelConfig) {
    this.config = config;
  }

  /**
   * Generate content using Gemini API
   */
  async generateContent(
    prompt: string,
    systemInstruction?: string,
    conversationHistory?: Array<{ role: "user" | "assistant"; content: string }>
  ): Promise<string> {
    const url = `${this.config.baseUrl}/models/${this.config.modelId}:generateContent?key=${this.config.apiKey}`;

    // Build contents array from conversation history
    const contents: any[] = [];

    // Convert conversation history to Gemini format
    if (conversationHistory) {
      for (const msg of conversationHistory) {
        contents.push({
          role: msg.role === "user" ? "user" : "model",
          parts: [{ text: msg.content }],
        });
      }
    }

    // Add current user prompt
    contents.push({
      role: "user",
      parts: [{ text: prompt }],
    });

    const requestBody: any = {
      contents: contents,
      generationConfig: {
        temperature: this.config.temperature || 0.7,
        maxOutputTokens: this.config.maxTokens || 8192,
      },
    };

    if (systemInstruction) {
      requestBody.systemInstruction = {
        parts: [{ text: systemInstruction }],
      };
    }

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
    }

    const data = await response.json();
    return data.candidates[0].content.parts[0].text;
  }

  /**
   * Stream content (for future use)
   */
  async *streamContent(
    prompt: string,
    systemInstruction?: string
  ): AsyncGenerator<string, void, unknown> {
    const url = `${this.config.baseUrl}/models/${this.config.modelId}:streamGenerateContent?key=${this.config.apiKey}`;

    const requestBody: any = {
      contents: [
        {
          role: "user",
          parts: [{ text: prompt }],
        },
      ],
      generationConfig: {
        temperature: this.config.temperature || 0.7,
        maxOutputTokens: this.config.maxTokens || 8192,
      },
    };

    if (systemInstruction) {
      requestBody.systemInstruction = {
        parts: [{ text: systemInstruction }],
      };
    }

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      throw new Error(`Gemini API streaming error: ${response.status}`);
    }

    // Parse SSE stream
    const reader = response.body?.getReader();
    const decoder = new TextDecoder();

    if (!reader) {
      throw new Error("No response body");
    }

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value);
      const lines = chunk.split("\n");

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const data = JSON.parse(line.slice(6));
          if (data.candidates?.[0]?.content?.parts?.[0]?.text) {
            yield data.candidates[0].content.parts[0].text;
          }
        }
      }
    }
  }
}

/**
 * Claude API Client
 * 
 * Supports Claude Haiku and Claude Sonnet
 */
export class ClaudeClient {
  private config: ModelConfig;

  constructor(config: ModelConfig) {
    this.config = config;
  }

  /**
   * Generate message using Claude API
   */
  async generateMessage(
    prompt: string,
    systemPrompt?: string,
    conversationHistory?: Array<{ role: "user" | "assistant"; content: string }>
  ): Promise<string> {
    const url = `${this.config.baseUrl}/messages`;

    const messages: any[] = [];

    if (conversationHistory) {
      messages.push(...conversationHistory);
    }

    messages.push({
      role: "user",
      content: prompt,
    });

    const requestBody: any = {
      model: this.config.modelId,
      max_tokens: this.config.maxTokens || 4096,
      temperature: this.config.temperature || 0.7,
      messages: messages,
    };

    if (systemPrompt) {
      requestBody.system = systemPrompt;
    }

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": this.config.apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Claude API error: ${response.status} - ${errorText}`);
    }

    const data = await response.json();
    return data.content[0].text;
  }

  /**
   * Stream messages (for future use)
   */
  async *streamMessage(
    prompt: string,
    systemPrompt?: string
  ): AsyncGenerator<string, void, unknown> {
    const url = `${this.config.baseUrl}/messages`;

    const requestBody: any = {
      model: this.config.modelId,
      max_tokens: this.config.maxTokens || 4096,
      temperature: this.config.temperature || 0.7,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
      stream: true,
    };

    if (systemPrompt) {
      requestBody.system = systemPrompt;
    }

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": this.config.apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      throw new Error(`Claude API streaming error: ${response.status}`);
    }

    const reader = response.body?.getReader();
    const decoder = new TextDecoder();

    if (!reader) {
      throw new Error("No response body");
    }

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value);
      const lines = chunk.split("\n");

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          try {
            const data = JSON.parse(line.slice(6));
            if (data.type === "content_block_delta" && data.delta?.text) {
              yield data.delta.text;
            }
          } catch (e) {
            // Skip invalid JSON
          }
        }
      }
    }
  }
}

/**
 * Local EIS Client (Future Implementation)
 * 
 * This would connect to a local inference server running EIS-O1 or EIS-E1
 * Example: http://localhost:8080/v1/chat/completions
 */
export class LocalEISClient {
  private config: ModelConfig;

  constructor(config: ModelConfig) {
    this.config = config;
  }

  /**
   * Generate content using local EIS model
   * 
   * TODO: Implement when local inference server is available
   * This would make HTTP requests to localhost inference server
   */
  async generateContent(
    prompt: string,
    systemPrompt?: string,
    conversationHistory?: Array<{ role: "user" | "assistant"; content: string }>
  ): Promise<string> {
    // Placeholder implementation
    // In production, this would:
    // 1. Check if local server is running
    // 2. Send request to local inference endpoint
    // 3. Parse response and return text
    
    throw new Error("Local EIS model not yet implemented");
  }
}

/**
 * LLM Client Factory
 * Creates the appropriate client based on model family
 */
export function createLLMClient(config: ModelConfig) {
  switch (config.family) {
    case "GEMINI_FLASH":
    case "GEMINI_PRO":
      return new GeminiClient(config);
    case "CLAUDE_HAIKU":
    case "CLAUDE_SONNET":
      return new ClaudeClient(config);
    case "LOCAL_EIS":
      return new LocalEISClient(config);
    default:
      throw new Error(`Unknown model family: ${config.family}`);
  }
}

