# Social-Publisher Plugin: Registration & Activation

## 1. Is SwarmSpace registering `social-publisher`?

**Yes.** The plugin is registered in the codebase:

- **Firebase Cloud Function (router):** `functions/src/functions/swarmspaceRouter.ts`  
  - `PLUGIN_REGISTRY["social-publisher"]` is defined (lines 165–173) with:
    - `workerUrl: "https://swarmspace-social-publisher.orbitalai.workers.dev"`
    - `requiredTier: "standard"`
    - `privacy_data_required: true`
- **Compiled output:** `functions/lib/functions/swarmspaceRouter.js` includes the same entry (lines 140–148).

The error **"Exception: Unknown plugin: social-publisher"** is thrown by the **deployed** Cloud Function when it looks up the plugin and doesn’t find it. So the live router is running an older build that doesn’t include `social-publisher`.

**Fix:** Redeploy the Firebase Cloud Functions so the deployed router uses the current registry (including `social-publisher`).

```bash
cd /Users/mymac/Software/Development/ARCv2.5/functions
npm run build
firebase deploy --only functions
# Or only the router: firebase deploy --only functions:swarmspaceRouter,functions:swarmspacePluginCatalog,functions:swarmspacePluginStatus
```

After deployment, the client’s call to `social-publisher` (e.g. `connectUrl`) will reach the router and be forwarded to the worker instead of returning "Unknown plugin".

---

## 2. Activating the social-publisher flow

Once the router knows about `social-publisher`, the flow is:

1. **App** → `SwarmSpaceClient.invoke("social-publisher", { _action: "connectUrl", platform, profileId })`
2. **Router** → checks tier, forwards POST to `https://swarmspace-social-publisher.orbitalai.workers.dev/invoke`
3. **Worker** → validates `SWARMSPACE_INTERNAL_TOKEN`, calls Late.com (or your own OAuth) and returns `{ connectUrl }`.

So you need:

- **Router:** Deploy functions (above).
- **Worker:** Deploy the Cloudflare Worker and set secrets (see `scripts/cloudflare-workers/social-publisher/README.md`):

  ```bash
  cd scripts/cloudflare-workers/social-publisher
  npm install
  npx wrangler deploy
  npx wrangler secret put SWARMSPACE_INTERNAL_TOKEN   # same value as in Firebase)
  npx wrangler secret put LATE_API_KEY                # from getlate.dev, or your own backend)
  ```

---

## 3. LinkedIn and Bluesky (implemented in worker)

The worker now implements **LinkedIn OAuth 2.0** and **Bluesky AT Protocol** directly (no Late.com required for these):

- **LinkedIn:** For `platform === "linkedin"`, `connectUrl` returns LinkedIn’s authorization URL. User is sent to LinkedIn, then to the worker’s public callback `GET /oauth/linkedin/callback`. The worker exchanges the code for tokens and stores them in KV under `linkedin:{userId}`.  
  **Setup:** Create an app in the [LinkedIn Developer Portal](https://www.linkedin.com/developers/apps), add redirect URL `https://<your-worker>.<your-domain>/oauth/linkedin/callback`, request “Share on LinkedIn”, set `LINKEDIN_CLIENT_ID` and `LINKEDIN_CLIENT_SECRET` as worker secrets.

- **Bluesky:** For `platform === "bluesky"`, `connectUrl` returns a worker URL that shows a small form (handle + app password). User submits; worker calls `com.atproto.server.createSession` on `bsky.social` and stores the session in KV under `bluesky:{userId}`.  
  **Setup:** No app credentials; users create an [App Password](https://docs.bsky.app/docs/advanced-guides/app-passwords) in Bluesky settings.

Other platforms (e.g. Threads, Twitter/X) still use **Late.com** when `LATE_API_KEY` is set. See `scripts/cloudflare-workers/social-publisher/README.md` for KV namespace creation and deploy steps.

---

## 4. Summary

| Item | Status / Action |
|------|------------------|
| SwarmSpace plugin registration in code | ✅ Registered in `swarmspaceRouter.ts` and compiled JS |
| "Unknown plugin: social-publisher" | Deployed Cloud Function is stale → **redeploy functions** |
| Connect URL resolving | After deploy: router forwards to worker; worker uses Late.com or your OAuth |
| LinkedIn | ✅ OAuth 2.0 in worker; set LINKEDIN_CLIENT_ID/SECRET and callback URL in LinkedIn Developer Portal |
| Bluesky | ✅ AT Protocol createSession in worker; users connect with handle + app password |

The UI (Connected Accounts, chips, getConnectUrl) is already in place; fixing the error and connect URL is deployment (router + worker) and, if needed, OAuth implementation in the worker (LinkedIn → Bluesky).
