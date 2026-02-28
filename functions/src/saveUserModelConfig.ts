// saveUserModelConfig.ts - Shared logic to validate and save user LLM config
// Used by updateUserModelConfig (callable) and sendChatMessage (in-chat flow)

import { admin } from "./admin";
import { encrypt } from "./crypto";
import { validateApiKey } from "./llmRouter";
import { canUseProjectKey, type ProviderId } from "./config/providers";

const db = admin.firestore();

/**
 * Save config using project's API key (no user key stored).
 * Only for groq and gemini.
 */
export async function saveUserModelConfigWithProjectKey(
  userId: string,
  provider: ProviderId,
  modelId: string
): Promise<void> {
  if (!canUseProjectKey(provider)) {
    throw new Error(`Provider ${provider} does not support project default`);
  }
  const settingsRef = db.collection("users").doc(userId).collection("settings").doc("llm");
  await settingsRef.set({
    provider,
    modelId: modelId.trim(),
    useProjectKey: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Validate API key and save encrypted config to Firestore.
 * For cloudflare, accountId is required.
 */
export async function saveUserModelConfig(
  userId: string,
  provider: ProviderId,
  modelId: string,
  apiKey: string,
  encryptionKey: string,
  accountId?: string
): Promise<void> {
  await validateApiKey(provider, modelId, apiKey, accountId);
  const apiKeyEncrypted = encrypt(apiKey, encryptionKey);
  const settingsRef = db.collection("users").doc(userId).collection("settings").doc("llm");
  const data: Record<string, unknown> = {
    provider,
    modelId: modelId.trim(),
    apiKeyEncrypted,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (accountId) data.accountId = accountId.trim();
  await settingsRef.set(data);
}
