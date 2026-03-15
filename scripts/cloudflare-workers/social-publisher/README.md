# SwarmSpace Social Publisher Worker

Proxies LUMARA → Late.com API. All requests require `Authorization: Bearer SWARMSPACE_INTERNAL_TOKEN`. The worker uses `LATE_API_KEY` to call Late.com; the key is never exposed to the client.

## Endpoints (via router POST /invoke)

Request body must include `_action` and action-specific params:

- **publish** — `{ _action: "publish", content, platforms: [{ platform, accountId }], mediaUrls?, scheduledFor?, timezone? }`
- **accounts** — `{ _action: "accounts", profileId? }`
- **profiles** — `{ _action: "profiles" }`
- **createProfile** — `{ _action: "createProfile", name, description? }`
- **connectUrl** — `{ _action: "connectUrl", platform, profileId, redirectUrl? }`
- **status** — `{ _action: "status", postId }`

## Deploy

```bash
npm install
npx wrangler deploy
npx wrangler secret put SWARMSPACE_INTERNAL_TOKEN
npx wrangler secret put LATE_API_KEY
```

Get `LATE_API_KEY` from https://getlate.dev (sign up, create API key).
