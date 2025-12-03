// types.ts - Core type definitions for the backend

import * as admin from "firebase-admin";

/**
 * Subscription tier types
 */
export type SubscriptionTier = "FREE" | "PAID";
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
  subscriptionTier: SubscriptionTier;
  subscriptionStatus: SubscriptionStatus;
  stripeCustomerId?: string;
  createdAt: admin.firestore.Timestamp;
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
 */
export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  timestamp: admin.firestore.Timestamp;
  modelUsed?: ModelFamily;
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
  };
}

/**
 * Analysis response structure
 */
export interface AnalysisResponse {
  summary: string;
  themes: string[];
  suggestions: string[];
  tier: SubscriptionTier;
  modelUsed: ModelFamily;
}

/**
 * Chat response structure
 */
export interface ChatResponse {
  threadId: string;
  message: ChatMessage;
  messageCount: number;
  modelUsed: ModelFamily;
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

