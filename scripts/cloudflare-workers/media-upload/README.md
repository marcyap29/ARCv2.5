# SwarmSpace R2 media upload worker

- **Route:** `swarmspace-media-upload.orbitalai.workers.dev`
- **POST /upload:** multipart/form-data (field: `file`, `image`, or `upload`). Auth: `Authorization: Bearer SWARMSPACE_INTERNAL_TOKEN`. Returns `{ url: string }`.
- **GET /media/{path}:** serves uploaded object from R2 (path format: `media/{uuid}.{ext}`).
- **Paths:** UUID v4 only — `crypto.randomUUID()` for every upload; no sequential IDs.

## Setup

1. Create R2 bucket `swarmspace-media` in Cloudflare dashboard.
2. (Optional) Set bucket lifecycle to delete objects after 24 hours for TTL.
3. `wrangler secret put SWARMSPACE_INTERNAL_TOKEN` (same value as Firebase).
4. (Optional) `wrangler secret put PUBLIC_MEDIA_BASE_URL` — custom domain base URL for returned links. If unset, returned URL uses this worker’s host.

## Deploy

```bash
cd scripts/cloudflare-workers/media-upload
npm init -y
npm i -D wrangler
npx wrangler deploy
```
