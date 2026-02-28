// userLlmSettings.ts - Load and decrypt per-user LLM settings

import { admin } from "./admin";
import { decrypt } from "./crypto";
import type { ProviderId } from "./config/providers";

export interface UserLlmConfig {
  provider: ProviderId;
  modelId: string;
  /** User's own API key; when useProjectKey is true, caller resolves from project secrets */
  apiKey?: string;
  /** Use project's API key (no user key stored). Only for groq/gemini. */
  useProjectKey?: boolean;
  /** Cloudflare Workers AI account ID (required when provider is cloudflare) */
  accountId?: string;
}

/**
 * Load user's LLM config from Firestore. Returns null if none set.
 * Decrypts API key using LLM_SETTINGS_ENCRYPTION_KEY.
 */
export async function loadUserLlmSettings(
  userId: string,
  encryptionKey: string
): Promise<UserLlmConfig | null> {
  const doc = await admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("settings")
    .doc("llm")
    .get();

  if (!doc.exists) return null;

  const data = doc.data();
  if (!data?.provider || !data?.modelId) {
    return null;
  }

  // useProjectKey: user chose project default (no API key stored)
  if (data.useProjectKey) {
    return {
      provider: data.provider as ProviderId,
      modelId: data.modelId,
      useProjectKey: true,
      accountId: data.accountId as string | undefined,
    };
  }

  if (!data.apiKeyEncrypted) return null;

  try {
    const apiKey = decrypt(data.apiKeyEncrypted, encryptionKey);
    return {
      provider: data.provider as ProviderId,
      modelId: data.modelId,
      apiKey,
      accountId: data.accountId as string | undefined,
    };
  } catch {
    return null;
  }
}
