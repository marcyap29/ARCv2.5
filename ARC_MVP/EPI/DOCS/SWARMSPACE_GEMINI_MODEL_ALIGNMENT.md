# SwarmSpace Gemini Flash — model alignment

All Gemini inference in this pipeline must use the **same** model so behavior is consistent.

## Required model

- **Model ID:** `gemini-3-flash-preview`

## Where it’s used in this repo

| Component | Location | Model |
|-----------|----------|--------|
| Firebase `proxyGemini` | `functions/src/functions/proxyGemini.ts` | `gemini-3-flash-preview` |
| Firebase `visionOcrInvoke` | `functions/src/functions/visionOcrInvoke.ts` | `gemini-3-flash-preview` |
| LLM router (effective model for swarmspace) | `functions/src/llmRouter.ts` | `gemini-3-flash-preview` |

## External worker (you must verify)

The **SwarmSpace Gemini Flash** plugin is served by an external Cloudflare Worker:

- **URL:** `https://swarmspace-plugin-gemini-flash.orbitalai.workers.dev`
- **Source:** Not in this repo. Workers are deployed separately (e.g. Orbital AI / SwarmSpace workers repo or Cloudflare dashboard).

**Requirement:** That worker **must** call the Gemini API with model **`gemini-3-flash-preview`**.  
If it uses an older model (e.g. `gemini-2.0-flash`, `gemini-1.5-flash`), you will get different quality and behavior than `proxyGemini` and `visionOcrInvoke`, and the pipeline will be inconsistent.

### How to confirm

1. Open the worker’s source (wherever `swarmspace-plugin-gemini-flash` is implemented).
2. Find where the Gemini client is configured (e.g. `getGenerativeModel({ model: "..." })` or equivalent).
3. Ensure the model string is **`gemini-3-flash-preview`**.
4. Redeploy the worker if you change it, then re-verify.

Once confirmed, you can note the check date here:

- **Last verified:** _[2026_03_13]_ — worker uses `gemini-3-flash-preview`
