"use strict";
// functions/src/functions/newsDataInvoke.ts
//
// SwarmSpace-compatible NewsData.io plugin — Firebase HTTP function
//
// Implements the SwarmSpace invoke contract so the swarmspaceRouter can forward
// news requests here. Uses your NewsData.io API key to fetch latest news.
//
// Flow:
//   swarmspaceRouter (on "news" plugin_id)
//     → POST to this function's /invoke path
//     → Validates Authorization: Bearer SWARMSPACE_INTERNAL_TOKEN
//     → Calls NewsData.io API
//     → Returns { results: [...] } in SwarmSpace format
//
// Set secrets:
//   firebase functions:secrets:set NEWSDATA_API_KEY
//   (SWARMSPACE_INTERNAL_TOKEN is already set for the router)
Object.defineProperty(exports, "__esModule", { value: true });
exports.newsDataInvoke = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const params_1 = require("firebase-functions/params");
const NEWSDATA_API_KEY = (0, params_1.defineSecret)("NEWSDATA_API_KEY");
const SWARMSPACE_INTERNAL_TOKEN = (0, params_1.defineSecret)("SWARMSPACE_INTERNAL_TOKEN");
const NEWSData_BASE = "https://newsdata.io/api/1/latest";
exports.newsDataInvoke = (0, https_1.onRequest)({
    secrets: [NEWSDATA_API_KEY, SWARMSPACE_INTERNAL_TOKEN],
    cors: true,
    invoker: "public", // Required for swarmspaceRouter to call via HTTP; auth via Bearer token
}, async (req, res) => {
    // Only accept POST (SwarmSpace invoke contract)
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    // Validate Authorization — must match SWARMSPACE_INTERNAL_TOKEN
    const authHeader = req.headers.authorization;
    const expectedToken = SWARMSPACE_INTERNAL_TOKEN.value();
    if (!authHeader || authHeader !== `Bearer ${expectedToken}`) {
        firebase_functions_1.logger.warn("newsDataInvoke: unauthorized request");
        res.status(403).json({ error: "Unauthorized" });
        return;
    }
    const apiKey = NEWSDATA_API_KEY.value();
    if (!apiKey || apiKey.trim() === "") {
        firebase_functions_1.logger.error("newsDataInvoke: NEWSDATA_API_KEY not configured");
        res.status(500).json({ error: "News API not configured" });
        return;
    }
    try {
        // Parse params from body (SwarmSpace passes { query, category?, country?, language? })
        const params = (typeof req.body === "object" ? req.body : {});
        const query = params.query ?? params.q ?? "news";
        const category = params.category;
        const country = params.country;
        const language = params.language ?? "en";
        const searchParams = new URLSearchParams({
            apikey: apiKey,
            q: String(query).trim() || "news",
            language,
        });
        if (category)
            searchParams.set("category", category);
        if (country)
            searchParams.set("country", country);
        const url = `${NEWSData_BASE}?${searchParams.toString()}`;
        const newsResponse = await fetch(url, {
            method: "GET",
            headers: { Accept: "application/json" },
            signal: AbortSignal.timeout(15000),
        });
        if (!newsResponse.ok) {
            const errText = await newsResponse.text();
            firebase_functions_1.logger.error(`NewsData.io API error ${newsResponse.status}: ${errText}`);
            res.status(502).json({
                error: "News service temporarily unavailable",
                details: newsResponse.status === 401 ? "Invalid API key" : undefined,
            });
            return;
        }
        const data = (await newsResponse.json());
        if (data.status === "error") {
            const msg = data.message ?? "News API error";
            firebase_functions_1.logger.warn(`NewsData.io error: ${msg}`);
            res.status(502).json({ error: msg });
            return;
        }
        const articles = data.results ?? [];
        const results = articles.map((a) => ({
            title: a.title ?? "",
            description: a.description ?? "",
            snippet: a.description ?? "",
            url: a.link ?? "",
            link: a.link ?? "",
            source: a.source_name ?? a.source_id ?? "news",
            domain: a.source_name ?? "news",
            pubDate: a.pubDate,
            published_date: a.pubDate,
        }));
        // SwarmSpace format — compatible with SwarmSpaceWebSearchTool / SearchSnippet
        res.status(200).json({
            results,
            totalResults: data.totalResults ?? results.length,
            status: "success",
        });
    }
    catch (err) {
        firebase_functions_1.logger.error("newsDataInvoke error:", err);
        res.status(500).json({
            error: err instanceof Error ? err.message : "News fetch failed",
        });
    }
});
//# sourceMappingURL=newsDataInvoke.js.map