// modelRouter.ts - Model selection and routing logic

import { ModelFamily, OperationType, SubscriptionTier, ModelConfig } from "./types";
import { getModelConfig } from "./config";

/**
 * Model Router
 * 
 * Selects the appropriate model based on:
 * - User subscription tier
 * - Operation type
 * - Model availability
 * 
 * Architecture:
 * Client → Firebase Auth → Cloud Function → Tier Resolver → Quota Checks → 
 * Model Router → Gemini/Claude Client → Response → Firestore Updates → Client
 */
export class ModelRouter {
  /**
   * Select the appropriate model for an operation
   * 
   * Routing Rules:
   * - FREE tier: Always Gemini Flash (backend enforces quotas: 4 analyses/entry, 200 messages/thread)
   * - PAID tier:
   *   - journal_analysis: Gemini 2.5 (unlimited)
   *   - deep_reflection: Claude Sonnet
   *   - chat_message: Gemini 2.5 (unlimited)
   *   - theme_extraction: Gemini 2.5
   *   - monthly_summary: Claude Sonnet
   * 
   * Note: FREE and PAID both use Gemini 2.5 - difference is backend quota enforcement, not model capability
   * 
   * Future: LOCAL_EIS can be selected when:
   * - Local inference server is available
   * - User opts in to local processing
   * - Operation doesn't require cloud features
   */
  static selectModel(
    tier: SubscriptionTier,
    operationType: OperationType
  ): ModelFamily {
    // Free tier: Always Gemini Flash
    if (tier === "FREE") {
      return "GEMINI_FLASH";
    }

    // Paid tier: Route based on operation type
    switch (operationType) {
      case "journal_analysis":
        return "GEMINI_PRO";
      
      case "deep_reflection":
        // Use Claude Sonnet for deeper, more nuanced reflections
        return "CLAUDE_SONNET";
      
      case "chat_message":
        // Default to Gemini Pro for chat (fast, cost-effective)
        // Could be made configurable per user preference
        return "GEMINI_PRO";
      
      case "theme_extraction":
        return "GEMINI_PRO";
      
      case "monthly_summary":
        // Use Claude Sonnet for comprehensive summaries
        return "CLAUDE_SONNET";
      
      default:
        // Fallback to Gemini Pro
        return "GEMINI_PRO";
    }
  }

  /**
   * Get model configuration for a selected model family
   */
  static getConfig(family: ModelFamily): ModelConfig {
    return getModelConfig(family);
  }

  /**
   * Future: Check if local model is available
   * This would check if EIS-O1/EIS-E1 inference server is running
   */
  static async isLocalModelAvailable(): Promise<boolean> {
    // TODO: Implement local model availability check
    // This would ping the local inference server
    // Example: http://localhost:8080/health
    return false;
  }

  /**
   * Future: Select model with local fallback
   * If local model is available and user prefers it, use local
   */
  static async selectModelWithLocal(
    tier: SubscriptionTier,
    operationType: OperationType,
    preferLocal: boolean = false
  ): Promise<ModelFamily> {
    if (preferLocal && await this.isLocalModelAvailable()) {
      // Check if operation is suitable for local processing
      if (operationType === "chat_message" || operationType === "journal_analysis") {
        return "LOCAL_EIS";
      }
    }
    
    return this.selectModel(tier, operationType);
  }
}

