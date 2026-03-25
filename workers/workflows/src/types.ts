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

export interface WorkflowRequest {
  input: string;
  persona_key?: string;
  platforms?: string[];
  chronicle_context?: ChronicleBundle;
  use_chronicle?: boolean;
}

export interface ChronicleBundle {
  profile: string;
  tags: string[];
  recent: string;
  topical: string;
}

export interface SSEMessage {
  type: 'step_start' | 'step_complete' | 'progress' | 'result' | 'error';
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
