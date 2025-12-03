// modelRouter.ts - Model selection and routing logic

import { ModelFamily, OperationType, SubscriptionTier, ModelConfig } from "./types";
import { getModelConfig } from "./config";

/**
 * Model Router
 * 
 * SYSTEM: LUMARA does not present API choices to the user.
 * The system uses Gemini as the default and primary inference engine.
 * Model selection is internal and upgradeable.
 * 
 * Architecture:
 * Client → Firebase Auth → Cloud Function → Rate Limiter → 
 * Model Router (Gemini by default) → Gemini Client → Response → Firestore Updates → Client
 */
export class ModelRouter {
  /**
   * Select the appropriate model for an operation
   * 
   * Routing Rules (INTERNAL ONLY - never exposed to users):
   * - Default: Always Gemini 2.5 (or Gemini 2.5 Flash for free tier)
   * - Failover: If Gemini unavailable, silently failover to backup (Claude)
   * - User never sees model selection or API provider names
   * 
   * Note: Model selection is completely internal. Users only see LUMARA responses.
   */
  static selectModel(
    tier: SubscriptionTier,
    operationType: OperationType
  ): ModelFamily {
    // Always use Gemini by default
    // FREE tier uses Flash, PAID uses Pro (same model, different quotas)
    if (tier === "FREE" || tier === "free") {
      return "GEMINI_FLASH";
    }
    
    // PAID/PRO tier uses Gemini Pro
    return "GEMINI_PRO";
  }

  /**
   * Check if Gemini is available, with silent failover
   * Returns the model to use (Gemini preferred, Claude as backup)
   */
  static async selectModelWithFailover(
    tier: SubscriptionTier,
    operationType: OperationType
  ): Promise<ModelFamily> {
    // Try Gemini first (always preferred)
    const primaryModel = this.selectModel(tier, operationType);
    
    // TODO: Implement health check for Gemini API
    // If Gemini unavailable, silently failover to Claude
    // const isGeminiAvailable = await this.checkGeminiHealth();
    // if (!isGeminiAvailable) {
    //   return "CLAUDE_HAIKU"; // Silent failover
    // }
    
    return primaryModel;
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

