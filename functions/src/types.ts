// types.ts - Core type definitions for the backend

import * as admin from "firebase-admin";

/**
 * Subscription tier types
 * Note: "PAID" is also referred to as "pro" in Stripe/webhook context
 */
export type SubscriptionTier = "FREE" | "PAID" | "free" | "pro";
export type SubscriptionStatus = "active" | "canceled" | "trial";

/**
 * Model family identifiers
 * Future-proof: Adding LOCAL_EIS for future local model support
 */
export type ModelFamily = "GEMINI_FLASH" | "GEMINI_PRO" | "CLAUDE_HAIKU" | "CLAUDE_SONNET" | "LOCAL_EIS";

/**
 * Operation types for routing decisions
 */
export type OperationType = "journal_analysis" | "deep_reflection" | "chat_message" | "theme_extraction" | "monthly_summary";

/**
 * User document structure in Firestore
 */
export interface UserDocument {
  userId: string;
  plan: "free" | "pro"; // Simplified plan field (maps to subscriptionTier)
  subscriptionTier?: SubscriptionTier; // Legacy field, use 'plan' instead
  subscriptionStatus?: SubscriptionStatus;
  stripeCustomerId?: string;
  stripeSubscriptionId?: string;
  throttleUnlocked?: boolean; // Password-protected throttle unlock (dev/admin feature)
  throttleUnlockedAt?: admin.firestore.Timestamp; // When throttle was unlocked
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

/**
 * Rate limit tracking document
 */
export interface RateLimitDocument {
  userId: string;
  requestsToday: number;
  requestsLastMinute: number;
  lastRequestTimestamp: admin.firestore.Timestamp;
  lastMinuteWindowStart: admin.firestore.Timestamp;
  lastDayWindowStart: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

/**
 * Journal entry document structure
 */
export interface JournalEntryDocument {
  userId: string;
  content: string;
  analysisCount: number;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

/**
 * Chat thread document structure
 */
export interface ChatThreadDocument {
  userId: string;
  messageCount: number;
  messages: ChatMessage[];
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

/**
 * Chat message structure
 * Note: modelUsed is internal only, not exposed to users
 */
export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  timestamp: admin.firestore.Timestamp;
  // modelUsed removed from user-facing structure (internal tracking only)
}

/**
 * Model configuration interface
 */
export interface ModelConfig {
  family: ModelFamily;
  modelId: string;
  apiKey: string;
  baseUrl: string;
  maxTokens?: number;
  temperature?: number;
}

/**
 * Quota check result
 */
export interface QuotaCheckResult {
  allowed: boolean;
  error?: {
    code: string;
    message: string;
    currentUsage: number;
    limit: number;
    upgradeRequired: boolean;
    tier: SubscriptionTier;
    retryAfter?: number; // Seconds until retry allowed
  };
}

/**
 * Analysis response structure
 * Note: modelUsed is removed from user-facing responses (internal only)
 */
export interface AnalysisResponse {
  summary: string;
  themes: string[];
  suggestions: string[];
  tier: SubscriptionTier;
  // modelUsed removed - not exposed to users
}

/**
 * Chat response structure
 * Note: modelUsed is removed from user-facing responses (internal only)
 */
export interface ChatResponse {
  threadId: string;
  message: ChatMessage;
  messageCount: number;
  // modelUsed removed - not exposed to users
}

/**
 * Error Types
 */
export interface TierLimitError {
  code: "ANALYSIS_LIMIT_REACHED" | "CHAT_LIMIT_REACHED" | "TIER_RESTRICTION";
  message: string;
  currentUsage: number;
  limit: number;
  upgradeRequired: boolean;
  tier: SubscriptionTier;
}

export interface APIError {
  code: string;
  message: string;
  details?: any;
}

