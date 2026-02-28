// functions/src/functions/swarmspaceRouter.ts
//
// SwarmSpace API Router — Firebase Cloud Function
//
// This is the "front door" to SwarmSpace. LUMARA calls this function,
// which checks who the user is, what plan they're on, then forwards
// the request to the right Cloudflare plugin worker.
//
// Flow:
//   LUMARA app
//     → Firebase Auth token (proves user identity)
//     → This function (swarmspaceRouter)
//         → Validate token (Firebase does this automatically)
//         → Load user from Firestore, check their plan
//         → Look up which worker URL handles the requested plugin
//         → Forward request to that worker, stamping it with:
//             - X-SwarmSpace-User-Id   (user's Firebase UID)
//             - X-SwarmSpace-User-Tier (free / standard / premium)
//             - Authorization: Bearer <SWARMSPACE_INTERNAL_TOKEN>
//         → Return the worker's response to LUMARA

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { enforceAuth } from "../authGuard";

// ── Secrets ────────────────────────────────────────────────────────────────────
// Set these once via Firebase CLI:
//   firebase functions:secrets:set SWARMSPACE_INTERNAL_TOKEN
//
// This is the shared secret between the router and the Cloudflare workers.
// Workers reject any request that doesn't have it — this prevents people
// from calling your workers directly and bypassing the auth/quota system.
const SWARMSPACE_INTERNAL_TOKEN = defineSecret("SWARMSPACE_INTERNAL_TOKEN");

// ── Plugin registry ────────────────────────────────────────────────────────────
// Maps plugin_id → { workerUrl, requiredTier }
// Add new plugins here as you deploy them.
//
// 'free'     = available to all signed-in users
// 'standard' = requires paid plan ($30/mo)
// 'premium'  = requires premium plan (future)

type Tier = "free" | "standard" | "premium";

interface PluginConfig {
  workerUrl: string;
  requiredTier: Tier;
}

const PLUGIN_REGISTRY: Record<string, PluginConfig> = {
  // ── Free tier ──────────────────────────────────────────────────────────────
  "gemini-flash": {
    workerUrl: "https://swarmspace-plugin-gemini-flash.orbitalai.workers.dev",
    requiredTier: "free",
  },
  "brave-search": {
    workerUrl: "https://swarmspace-plugin-brave-search.orbitalai.workers.dev",
    requiredTier: "free",
  },
  "semantic-scholar": {
    workerUrl: "https://swarmspace-plugin-semantic-scholar.orbitalai.workers.dev",
    requiredTier: "free",
  },
  "weather": {
    workerUrl: "https://swarmspace-plugin-weather.orbitalai.workers.dev",
    requiredTier: "free",
  },
  "wikipedia": {
    workerUrl: "https://swarmspace-plugin-wikipedia.orbitalai.workers.dev",
    requiredTier: "free",
  },
  "currency": {
    workerUrl: "https://swarmspace-plugin-currency.orbitalai.workers.dev",
    requiredTier: "free",
  },
  "news": {
    workerUrl: "https://swarmspace-plugin-news.orbitalai.workers.dev",
    requiredTier: "free",
  },
  // ── Standard tier ($30/mo) ─────────────────────────────────────────────────
  "url-reader": {
    workerUrl: "https://swarmspace-plugin-url-reader.orbitalai.workers.dev",
    requiredTier: "standard",
  },
  "tavily-search": {
    workerUrl: "https://swarmspace-plugin-tavily-search.orbitalai.workers.dev",
    requiredTier: "standard",
  },
  // ── Premium tier ──────────────────────────────────────────────────────────
  "exa-search": {
    workerUrl: "https://swarmspace-plugin-exa-search.orbitalai.workers.dev",
    requiredTier: "premium",
  },
  "perplexity-sonar": {
    workerUrl: "https://swarmspace-plugin-perplexity-sonar.orbitalai.workers.dev",
    requiredTier: "premium",
  },
};

// ── Tier resolution ────────────────────────────────────────────────────────────
// Maps your existing plan names to SwarmSpace tier names.
// Your Firestore users have plan: "free" | "pro"
// SwarmSpace workers understand: "free" | "standard" | "premium"
function resolveSwarmSpaceTier(plan: string, isPremium: boolean): Tier {
  if (!isPremium) return "free";
  // Right now "pro" maps to "standard". When you add a higher tier, map it to "premium".
  return "standard";
}

// ── Tier access check ──────────────────────────────────────────────────────────
// Returns true if the user's tier meets the plugin's requirement.
const TIER_RANK: Record<Tier, number> = { free: 0, standard: 1, premium: 2 };

function canAccessPlugin(userTier: Tier, requiredTier: Tier): boolean {
  return TIER_RANK[userTier] >= TIER_RANK[requiredTier];
}

// ── The router function ────────────────────────────────────────────────────────
export const swarmspaceRouter = onCall(
  {
    secrets: [SWARMSPACE_INTERNAL_TOKEN],
  },
  async (request) => {
    // Step 1: Verify the user is logged in (Firebase handles token validation automatically).
    // This is exactly the same pattern as your existing proxyGemini function.
    const { userId, isPremium, user } = await enforceAuth(request);

    // Step 2: Parse the request — LUMARA sends { plugin_id, params }
    const { plugin_id, params } = request.data ?? {};

    if (!plugin_id || typeof plugin_id !== "string") {
      throw new HttpsError("invalid-argument", "plugin_id is required");
    }

    // Step 3: Look up the plugin in the registry.
    // If it's not registered, we reject it — no unknown plugins allowed.
    const plugin = PLUGIN_REGISTRY[plugin_id];
    if (!plugin) {
      throw new HttpsError("not-found", `Unknown plugin: ${plugin_id}`);
    }

    // Step 4: Check if the user's plan allows this plugin.
    // e.g. a free user asking for "tavily-search" (standard) gets a clean error.
    const userTier = resolveSwarmSpaceTier(user.plan ?? "free", isPremium);
    if (!canAccessPlugin(userTier, plugin.requiredTier)) {
      throw new HttpsError(
        "permission-denied",
        `Plugin "${plugin_id}" requires the ${plugin.requiredTier} plan. ` +
          `You are on the ${userTier} plan.`,
        {
          plugin_id,
          required_tier: plugin.requiredTier,
          user_tier: userTier,
          upgrade_url: "https://swarmspace.ai/upgrade",
        }
      );
    }

    logger.info(
      `SwarmSpace router: user=${userId} tier=${userTier} plugin=${plugin_id}`
    );

    // Step 5: Forward the request to the Cloudflare worker.
    // We stamp it with three headers the worker requires:
    //   - Authorization        → proves this came from our router (not from the internet)
    //   - X-SwarmSpace-User-Id → so the worker knows whose quota to check
    //   - X-SwarmSpace-User-Tier → so the worker knows what limits to apply
    const internalToken = SWARMSPACE_INTERNAL_TOKEN.value();
    const workerUrl = `${plugin.workerUrl}/invoke`;

    let workerResponse: Response;
    try {
      workerResponse = await fetch(workerUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${internalToken}`,
          "X-SwarmSpace-User-Id": userId,
          "X-SwarmSpace-User-Tier": userTier,
        },
        body: JSON.stringify(params ?? {}),
        // 25 second timeout — Firebase functions time out at 60s,
        // this leaves headroom for our own error handling
        signal: AbortSignal.timeout(25_000),
      });
    } catch (err: any) {
      logger.error(`Worker fetch failed for plugin ${plugin_id}:`, err);
      throw new HttpsError(
        "unavailable",
        `Plugin ${plugin_id} is temporarily unavailable. Try again shortly.`
      );
    }

    // Step 6: Parse and return the worker's response.
    // We pass it through as-is — quota info, results, everything.
    let workerBody: unknown;
    try {
      workerBody = await workerResponse.json();
    } catch {
      throw new HttpsError("internal", `Plugin ${plugin_id} returned invalid response`);
    }

    // If the worker returned an error (e.g. quota exceeded), surface it cleanly.
    if (!workerResponse.ok) {
      const body = workerBody as Record<string, unknown>;
      const workerError = (body?.error as string) ?? "Plugin error";
      logger.warn(
        `Plugin ${plugin_id} returned ${workerResponse.status}: ${workerError}`
      );

      // 429 = quota exceeded — this is expected, not a crash
      if (workerResponse.status === 429) {
        throw new HttpsError("resource-exhausted", workerError, {
          plugin_id,
          quota: body?.quota,
        });
      }

      // 403 = tier insufficient (shouldn't happen since we check above, but belt+suspenders)
      if (workerResponse.status === 403) {
        throw new HttpsError("permission-denied", workerError);
      }

      throw new HttpsError("internal", workerError);
    }

    logger.info(`SwarmSpace plugin ${plugin_id} success for user ${userId}`);

    // Return the worker's response body to LUMARA
    return workerBody;
  }
);

// ── Plugin status endpoint ─────────────────────────────────────────────────────
// LUMARA calls this to check if a plugin is available for the current user.
// Lightweight — no quota consumed, no worker called.
export const swarmspacePluginStatus = onCall(
  {},
  async (request) => {
    const { userId: _userId, isPremium, user } = await enforceAuth(request);
    const userId = _userId;
    const { plugin_id } = request.data ?? {};

    if (!plugin_id || typeof plugin_id !== "string") {
      throw new HttpsError("invalid-argument", "plugin_id is required");
    }

    const plugin = PLUGIN_REGISTRY[plugin_id];
    if (!plugin) {
      return { available: false, reason: "unknown_plugin" };
    }

    const userTier = resolveSwarmSpaceTier(user.plan ?? "free", isPremium);
    const available = canAccessPlugin(userTier, plugin.requiredTier);

    return {
      available,
      plugin_id,
      user_tier: userTier,
      required_tier: plugin.requiredTier,
      reason: available ? null : "tier_insufficient",
      upgrade_url: available ? null : "https://swarmspace.ai/upgrade",
    };
  }
);