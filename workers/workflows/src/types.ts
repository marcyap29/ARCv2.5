export interface Env {
  GEMINI_API_KEY: string;
  GROQ_API_KEY: string;
  BRAVE_API_KEY: string;
  GEMINI_MODEL: string;
  GROQ_FAST_MODEL: string;
  GROQ_SMART_MODEL: string;
  GROQ_SYNTH_MODEL: string;
  JINA_BASE_URL: string;
}

export interface SourceDocument {
  name: string;
  text: string;
}

export interface ChronicleSemanticHit {
  snippet: string;
  score?: number;
  entry_date?: string;
}

export interface WorkflowRequest {
  input: string;
  persona_key?: string;
  platforms?: string[];
  chronicle_context?: ChronicleBundle;
  use_chronicle?: boolean;
  /** Extracted PDF / text attachments from the client (truncated server-side if huge). */
  source_documents?: SourceDocument[];
  /** Mirrors app `writing_preferences` (format, task, include_sources, …). */
  writing_preferences?: Record<string, unknown>;
  /** After the user answers clarifying questions, set true so the writer does not loop. */
  skip_writer_clarification?: boolean;
}

export interface ChronicleBundle {
  profile: string;
  tags: string[];
  recent: string;
  topical: string;
  /** Hybrid semantic + keyword CHRONICLE matches for this topic (client-built). */
  semantic_hits?: ChronicleSemanticHit[];
  /** Instruction for the model: confirm relevance with the user when weaving these in. */
  integration_note?: string;
}

export interface SSEMessage {
  type:
    | 'step_start'
    | 'step_complete'
    | 'progress'
    | 'result'
    | 'error'
    | 'clarification_needed';
  step?: string;
  message?: string;
  data?: unknown;
}

export interface SearchResult {
  title: string;
  url: string;
  description: string;
}

export interface CompetitiveCard {
  name: string;
  tagline: string;
  pricing: {
    model: string;
    tiers: unknown[];
    notes: string;
  } | null;
  core_features: string[];
  target_customer: string;
  strengths: string[];
  weaknesses: string[];
  recent_moves: string[];
  threat_level: string;
  threat_rationale: string;
}

export interface ApiAnalysis {
  api_name: string;
  provider: string;
  what_it_does: string;
  free_tier: string | null;
  paid_pricing: string | null;
  auth_method: string;
  rate_limits: string | null;
  latency_class: string;
  data_sent_to_api: string;
  suitable_for_ai_agents: boolean;
  concern: string | null;
}

export interface ScoredCandidate {
  api_name: string;
  recommended: boolean;
  recommended_tier: string;
  score_rationale: string;
}
