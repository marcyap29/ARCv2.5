// functions/generateJournalPrompts.ts - Journal prompt generation Cloud Function
// Uses Groq (GPT-OSS 120B) - aligned with Flutter LUMARA

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { admin } from "../admin";
import { checkUnifiedDailyLimit, checkRateLimit } from "../rateLimiter";
import { UserDocument } from "../types";
import { GROQ_API_KEY } from "../config";
import { groqChatCompletion } from "../groqClient";

const db = admin.firestore();

/**
 * Generate journaling prompts
 * 
 * Flow:
 * 1. Verify Firebase Auth token (automatic via onCall)
 * 2. Load user from Firestore
 * 3. Check rate limit
 * 4. Uses Groq (GPT-OSS 120B) for prompt generation
 * 5. Generate prompts using LLM with journal prompt generator system prompt
 * 6. Return prompts (4 initial or 12-18 expanded)
 * 
 * API Shape:
 * httpsCallable('generateJournalPrompts')
 * 
 * Request: { expanded: boolean, context?: { recentEntries?: string[], recentChats?: string[], currentPhase?: string } }
 * Response: { prompts: string[] }
 */
export const generateJournalPrompts = onCall(
  {
    secrets: [GROQ_API_KEY],
  },
  async (request) => {
    const { expanded = false, context } = request.data || {};

    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    logger.info(`Generating journal prompts (expanded: ${expanded}) for user ${userId}`);

    try {
      // Load user document
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        throw new HttpsError("not-found", "User not found");
      }

      const user = userDoc.data() as UserDocument;
      void user; // Reserved for future tier-based logic
      const userEmail = request.auth?.token?.email as string | undefined;

      // Unified daily limit: 50 total LUMARA requests/day (chat + reflections + voice)
      const dailyCheck = await checkUnifiedDailyLimit(userId, userEmail);
      if (!dailyCheck.allowed) {
        throw new HttpsError(
          "resource-exhausted",
          dailyCheck.error?.message || "Daily limit reached",
          dailyCheck.error
        );
      }

      // Per-minute spam protection
      const rateLimitCheck = await checkRateLimit(userId, userEmail);
      if (!rateLimitCheck.allowed) {
        throw new HttpsError(
          "resource-exhausted",
          rateLimitCheck.error?.message || "Rate limit exceeded",
          rateLimitCheck.error
        );
      }

      const apiKey = GROQ_API_KEY.value();
      if (!apiKey) {
        throw new HttpsError("internal", "Groq API key not configured");
      }
      logger.info(`Using Groq (GPT-OSS 120B) for journal prompts`);

      // Build context string from provided context
      let contextString = "";
      if (context) {
        if (context.recentEntries && context.recentEntries.length > 0) {
          contextString += `Recent journal entries:\n${context.recentEntries.slice(0, 5).join("\n\n")}\n\n`;
        }
        if (context.recentChats && context.recentChats.length > 0) {
          contextString += `Recent chat sessions:\n${context.recentChats.slice(0, 3).join("\n\n")}\n\n`;
        }
        if (context.currentPhase) {
          contextString += `Current ATLAS phase: ${context.currentPhase}\n\n`;
        }
      }

      // Build system prompt for journal prompt generation
      const systemPrompt = `You are LUMARA, the Life-aware Unified Memory and Reflection Assistant built on the EPI stack.

# **LUMARA — Journal Prompt Generator (System Prompt)**

**Purpose:** Generate journaling prompts that adapt to the user's context, keep the initial UI simple, and offer a deeper menu when expanded.

---

## **Behavior**

### **1. Initial Prompt Set (4 items total)**

When asked to generate initial prompts, produce **exactly 4 prompts** in this order:

1. **Contextual Prompt**
   Use the user's recent journal entries, emotional themes, or conversational threads to create a prompt that feels directly relevant.

2. **Fun / Playful / Light Prompt**
   Use moments from the user's journals that reflect joy, humor, warmth, or meaningful memories. Make it playful but not childish. Avoid cringe.

3. **Deep / Inspirational Prompt**
   Use thematic depth from the user's narrative history. This should evoke reflection without being poetic or vague. It should have clear developmental intent.

4. **Unrelated Prompt**
   Offer something deliberately orthogonal to the user's current context. This gives them a cognitive pivot and avoids monotony.

**Formatting:**
Return the 4 prompts as a clear, numbered list (1. 2. 3. 4.).

---

### **2. Expanded Prompt List (when the user taps "See more")**

When asked for expanded prompts, generate a longer list (12–18 items).

The list must follow a **rough 33/33/33 mix** of:

* **Contextual prompts** grounded in the user's journals and chats
* **Fun or playful prompts** (light tone, grounded in meaningful or joyful memories when possible)
* **Deep prompts** (inspirational or high-context)

Rules:

* Do not cluster the categories. Mix them.
* No category labeling. Just prompts.
* Avoid repetition of the initial 4 prompts.
* Prompts should vary in perspective (past reflection, present observation, future orientation, identity inquiries, phase-linked themes, etc.)

**Formatting:**
Return the prompts as a bulleted list (• prompt).

---

### **3. General Rules**

* Keep every prompt short, specific, and cognitively actionable.
* No generic platitudes.
* No "How does that make you feel?"-type clichés.
* Use the user's ATLAS phase when relevant but do not mention ATLAS explicitly.
* When drawing from context, stay grounded in the user's actual entries instead of inventing details.
* Maintain narrative dignity and emotional safety.
* Keep the tone steady, structured, and clear.

---

## **User Context**

${contextString || "No specific context provided. Generate prompts that are meaningful but not overly specific."}

---

**IMPORTANT:** 
- If generating initial prompts, return exactly 4 numbered prompts.
- If generating expanded prompts, return 12-18 bulleted prompts in a mixed 33/33/33 ratio.
- Do not include any explanation or meta-commentary, only the prompts themselves.`;

      // Build user message
      const userMessage = expanded
        ? "Generate an expanded list of 12-18 journaling prompts using the 33/33/33 mix rule. Return only the prompts as a bulleted list."
        : "Generate exactly 4 initial journaling prompts (1 contextual, 1 fun/playful, 1 deep/inspirational, 1 unrelated). Return only the numbered prompts (1. 2. 3. 4.).";

      // Generate prompts using Groq
      const promptsText = await groqChatCompletion(apiKey, {
        system: systemPrompt,
        user: userMessage,
        temperature: 0.7,
        maxTokens: 4096,
      });

      // Parse prompts from response
      const prompts: string[] = [];
      
      if (expanded) {
        // Parse bulleted list (• or -)
        const lines = promptsText.split("\n");
        for (const line of lines) {
          const trimmed = line.trim();
          if (trimmed.startsWith("•") || trimmed.startsWith("-") || trimmed.match(/^\d+\./)) {
            const prompt = trimmed.replace(/^[•\-\d\.]\s*/, "").trim();
            if (prompt.length > 0) {
              prompts.push(prompt);
            }
          }
        }
        // Ensure we have 12-18 prompts
        if (prompts.length < 12) {
          // If we got fewer, pad with variations
          logger.warn(`Got only ${prompts.length} expanded prompts, expected 12-18`);
        }
        if (prompts.length > 18) {
          prompts.splice(18);
        }
      } else {
        // Parse numbered list (1. 2. 3. 4.)
        const lines = promptsText.split("\n");
        for (const line of lines) {
          const trimmed = line.trim();
          const match = trimmed.match(/^(\d+)\.\s*(.+)$/);
          if (match) {
            const prompt = match[2].trim();
            if (prompt.length > 0) {
              prompts.push(prompt);
            }
          }
        }
        // Ensure we have exactly 4 prompts
        if (prompts.length !== 4) {
          logger.warn(`Got ${prompts.length} initial prompts, expected 4`);
          // If we got more, take first 4; if fewer, we'll return what we have
          if (prompts.length > 4) {
            prompts.splice(4);
          }
        }
      }

      if (prompts.length === 0) {
        // Fallback prompts if parsing failed
        if (expanded) {
          prompts.push(
            "What patterns do you notice in your recent entries?",
            "Describe a moment of joy from this week.",
            "What question have you been avoiding?",
            "Write about something you're grateful for.",
            "What would you tell your past self?",
            "Describe a challenge and what you've learned.",
            "What does growth look like for you right now?",
            "Write about a relationship that has changed.",
            "What are you curious about exploring?",
            "Describe a moment of clarity.",
            "What values are most important to you now?",
            "How has your perspective shifted recently?"
          );
        } else {
          prompts.push(
            "What patterns do you notice in your recent entries?",
            "Describe a moment of joy from this week.",
            "What question have you been avoiding?",
            "Write about something you're grateful for."
          );
        }
      }

      return {
        prompts,
        count: prompts.length,
      };
    } catch (error: any) {
      logger.error("Error generating journal prompts:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", `Failed to generate prompts: ${error.message}`);
    }
  }
);
