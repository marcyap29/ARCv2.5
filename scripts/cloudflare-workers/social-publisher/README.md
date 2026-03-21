# SwarmSpace Social Publisher Worker

Proxies LUMARA → Late.com for some platforms; **LinkedIn** and **Bluesky** use built-in OAuth/AT Protocol and store tokens in KV.

- **LinkedIn:** OAuth 2.0 — `connectUrl` returns LinkedIn auth URL; user is redirected to `/oauth/linkedin/callback`, worker exchanges code for tokens and stores them in KV.
- **Bluesky:** AT Protocol — `connectUrl` returns a worker URL that shows a form for handle + app password; worker calls `createSession`, stores tokens in KV.
- **Other platforms:** Still proxied to Late.com when `LATE_API_KEY` is set.

All `/invoke` requests require `Authorization: Bearer SWARMSPACE_INTERNAL_TOKEN`. Public routes: `GET /oauth/linkedin/callback`, `GET /connect/bluesky`, `POST /connect/bluesky`, `GET /connected`.

## Endpoints (via router POST /invoke)

Request body must include `_action` and action-specific params:

- **publish** — `{ _action: "publish", content, platforms: [{ platform, accountId }], mediaUrls?, scheduledFor?, timezone? }`
- **accounts** — `{ _action: "accounts", profileId? }`
- **profiles** — `{ _action: "profiles" }`
- **createProfile** — `{ _action: "createProfile", name, description? }`
- **connectUrl** — `{ _action: "connectUrl", platform, profileId, redirectUrl? }` — for `platform: "linkedin"` or `"bluesky"` uses built-in flow; else Late.com.
- **status** — `{ _action: "status", postId }`

## Deploy

### 1. Create KV namespace

```bash
npx wrangler kv namespace create "SOCIAL_PUBLISHER_KV"
```

Copy the returned `id` and set it in `wrangler.toml` under `kv_namespaces[0].id` (replace `REPLACE_AFTER_KV_CREATE`).

### 2. Deploy and set secrets

```bash
npm install
npx wrangler deploy
npx wrangler secret put SWARMSPACE_INTERNAL_TOKEN
npx wrangler secret put LATE_API_KEY
```

### 3. LinkedIn (optional)

1. Create an app at [LinkedIn Developer Portal](https://www.linkedin.com/developers/apps).
2. In the app, **Auth** tab: add **Redirect URL** exactly:  
   `https://swarmspace-social-publisher.orbitalai.workers.dev/oauth/linkedin/callback`  
   (Use your worker URL if different.)
3. Under **Products**, request **Share on LinkedIn** (for `w_member_social`).
4. Copy **Client ID** and **Client Secret** and set:

```bash
npx wrangler secret put LINKEDIN_CLIENT_ID
npx wrangler secret put LINKEDIN_CLIENT_SECRET
```

### 4. Bluesky

No app credentials needed. Users connect with their Bluesky **handle** and an **App Password** (Bluesky → Settings → App passwords). The worker calls `com.atproto.server.createSession` on `bsky.social`.

## Token storage (KV)

- **OAuth state:** `oauth_state:{stateId}` — short-lived (10 min), holds `{ userId, profileId, redirectUrl }`.
- **LinkedIn:** `linkedin:{userId}` — JSON `{ access_token, refresh_token?, expires_in, scope? }`.
- **Bluesky:** `bluesky:{userId}` — JSON `{ accessJwt, refreshJwt, handle, did }`.

`userId` is the SwarmSpace (Firebase) UID from the router header `X-SwarmSpace-User-Id`.
