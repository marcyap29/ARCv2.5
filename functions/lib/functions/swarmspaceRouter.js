"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.swarmspacePluginStatus = exports.swarmspaceRouter = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const params_1 = require("firebase-functions/params");
const authGuard_1 = require("../authGuard");
const userLlmSettings_1 = require("../userLlmSettings");
const config_1 = require("../config");
// ── Secrets ────────────────────────────────────────────────────────────────────
// Set these once via Firebase CLI:
//   firebase functions:secrets:set SWARMSPACE_INTERNAL_TOKEN
//
// This is the shared secret between the router and the Cloudflare workers.
// Workers reject any request that doesn't have it — this prevents people
// from calling your workers directly and bypassing the auth/quota system.
const SWARMSPACE_INTERNAL_TOKEN = (0, params_1.defineSecret)("SWARMSPACE_INTERNAL_TOKEN");
const PLUGIN_REGISTRY = {
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
function resolveSwarmSpaceTier(plan, isPremium) {
    if (!isPremium)
        return "free";
    // Right now "pro" maps to "standard". When you add a higher tier, map it to "premium".
    return "standard";
}
// ── Tier access check ──────────────────────────────────────────────────────────
// Returns true if the user's tier meets the plugin's requirement.
const TIER_RANK = { free: 0, standard: 1, premium: 2 };
function canAccessPlugin(userTier, requiredTier) {
    return TIER_RANK[userTier] >= TIER_RANK[requiredTier];
}
// ── The router function ────────────────────────────────────────────────────────
/** Plugin IDs that accept per-user API key override (LLM plugins) */
const LLM_PLUGINS = new Set(["gemini-flash"]);
exports.swarmspaceRouter = (0, https_1.onCall)({
    secrets: [SWARMSPACE_INTERNAL_TOKEN, config_1.LLM_SETTINGS_ENCRYPTION_KEY],
}, async (request) => {
    // Step 1: Verify the user is logged in (Firebase handles token validation automatically).
    // This is exactly the same pattern as your existing proxyGemini function.
    const { userId, isPremium, user } = await (0, authGuard_1.enforceAuth)(request);
    // Step 2: Parse the request — LUMARA sends { plugin_id, params }
    const { plugin_id, params } = request.data ?? {};
    if (!plugin_id || typeof plugin_id !== "string") {
        throw new https_1.HttpsError("invalid-argument", "plugin_id is required");
    }
    // Step 3: Look up the plugin in the registry.
    // If it's not registered, we reject it — no unknown plugins allowed.
    const plugin = PLUGIN_REGISTRY[plugin_id];
    if (!plugin) {
        throw new https_1.HttpsError("not-found", `Unknown plugin: ${plugin_id}`);
    }
    // Step 4: Check if the user's plan allows this plugin.
    // e.g. a free user asking for "tavily-search" (standard) gets a clean error.
    const userTier = resolveSwarmSpaceTier(user.plan ?? "free", isPremium);
    if (!canAccessPlugin(userTier, plugin.requiredTier)) {
        throw new https_1.HttpsError("permission-denied", `Plugin "${plugin_id}" requires the ${plugin.requiredTier} plan. ` +
            `You are on the ${userTier} plan.`, {
            plugin_id,
            required_tier: plugin.requiredTier,
            user_tier: userTier,
            upgrade_url: "https://swarmspace.ai/upgrade",
        });
    }
    firebase_functions_1.logger.info(`SwarmSpace router: user=${userId} tier=${userTier} plugin=${plugin_id}`);
    // Step 4b: For LLM plugins, pass user's API key if they have custom config
    let paramsToSend = params ?? {};
    if (LLM_PLUGINS.has(plugin_id)) {
        const encKey = config_1.LLM_SETTINGS_ENCRYPTION_KEY.value();
        if (encKey) {
            const userLlm = await (0, userLlmSettings_1.loadUserLlmSettings)(userId, encKey);
            if (userLlm && (userLlm.provider === "gemini" || userLlm.provider === "swarmspace")) {
                paramsToSend = { ...paramsToSend, _apiKeyOverride: userLlm.apiKey };
            }
        }
    }
    // Step 5: Forward the request to the Cloudflare worker.
    // We stamp it with three headers the worker requires:
    //   - Authorization        → proves this came from our router (not from the internet)
    //   - X-SwarmSpace-User-Id → so the worker knows whose quota to check
    //   - X-SwarmSpace-User-Tier → so the worker knows what limits to apply
    const internalToken = SWARMSPACE_INTERNAL_TOKEN.value();
    const workerUrl = `${plugin.workerUrl}/invoke`;
    let workerResponse;
    try {
        workerResponse = await fetch(workerUrl, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${internalToken}`,
                "X-SwarmSpace-User-Id": userId,
                "X-SwarmSpace-User-Tier": userTier,
            },
            body: JSON.stringify(paramsToSend),
            // 25 second timeout — Firebase functions time out at 60s,
            // this leaves headroom for our own error handling
            signal: AbortSignal.timeout(25000),
        });
    }
    catch (err) {
        firebase_functions_1.logger.error(`Worker fetch failed for plugin ${plugin_id}:`, err);
        throw new https_1.HttpsError("unavailable", `Plugin ${plugin_id} is temporarily unavailable. Try again shortly.`);
    }
    // Step 6: Parse and return the worker's response.
    // We pass it through as-is — quota info, results, everything.
    let workerBody;
    try {
        workerBody = await workerResponse.json();
    }
    catch {
        throw new https_1.HttpsError("internal", `Plugin ${plugin_id} returned invalid response`);
    }
    // If the worker returned an error (e.g. quota exceeded), surface it cleanly.
    if (!workerResponse.ok) {
        const body = workerBody;
        const workerError = body?.error ?? "Plugin error";
        firebase_functions_1.logger.warn(`Plugin ${plugin_id} returned ${workerResponse.status}: ${workerError}`);
        // 429 = quota exceeded — this is expected, not a crash
        if (workerResponse.status === 429) {
            throw new https_1.HttpsError("resource-exhausted", workerError, {
                plugin_id,
                quota: body?.quota,
            });
        }
        // 403 = tier insufficient (shouldn't happen since we check above, but belt+suspenders)
        if (workerResponse.status === 403) {
            throw new https_1.HttpsError("permission-denied", workerError);
        }
        throw new https_1.HttpsError("internal", workerError);
    }
    firebase_functions_1.logger.info(`SwarmSpace plugin ${plugin_id} success for user ${userId}`);
    // Return the worker's response body to LUMARA
    return workerBody;
});
// ── Plugin status endpoint ─────────────────────────────────────────────────────
// LUMARA calls this to check if a plugin is available for the current user.
// Lightweight — no quota consumed, no worker called.
exports.swarmspacePluginStatus = (0, https_1.onCall)({}, async (request) => {
    const { isPremium, user } = await (0, authGuard_1.enforceAuth)(request);
    const { plugin_id } = request.data ?? {};
    if (!plugin_id || typeof plugin_id !== "string") {
        throw new https_1.HttpsError("invalid-argument", "plugin_id is required");
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
});
//# sourceMappingURL=swarmspaceRouter.js.map