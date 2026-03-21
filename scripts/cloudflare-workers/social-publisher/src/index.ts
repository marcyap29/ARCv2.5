/**
 * SwarmSpace Social Publisher Worker
 * - Proxies LUMARA → Late.com API when using Late.com.
 * - LinkedIn: OAuth 2.0 connectUrl + callback, tokens stored in KV.
 * - Bluesky: AT Protocol createSession (handle + app password), tokens in KV.
 * Auth for /invoke: Authorization: Bearer SWARMSPACE_INTERNAL_TOKEN
 * Public routes: GET /oauth/linkedin/callback, GET/POST /connect/bluesky
 */

import { buildLinkedInAuthUrl, exchangeLinkedInCode } from "./linkedin";
import { createBlueskySession } from "./bluesky";

export interface Env {
  SWARMSPACE_INTERNAL_TOKEN: string;
  LATE_API_KEY: string;
  SOCIAL_KV: KVNamespace;
  LINKEDIN_CLIENT_ID?: string;
  LINKEDIN_CLIENT_SECRET?: string;
}

const LATE_BASE = "https://getlate.dev/api/v1";
const OAUTH_STATE_TTL = 600; // 10 minutes

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
  };
}

function jsonResponse(body: object, status: number, init?: ResponseInit): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
    ...init,
  });
}

function htmlResponse(html: string, status = 200): Response {
  return new Response(html, {
    status,
    headers: { "Content-Type": "text/html;charset=utf-8", ...corsHeaders() },
  });
}

function redirectResponse(url: string, status = 302): Response {
  return new Response(null, {
    status,
    headers: { Location: url, ...corsHeaders() },
  });
}

async function lateFetch(
  path: string,
  method: string,
  env: Env,
  body?: object,
  query?: Record<string, string>
): Promise<Response> {
  const url = new URL(`${LATE_BASE}${path}`);
  if (query) {
    Object.entries(query).forEach(([k, v]) => url.searchParams.set(k, v));
  }
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${env.LATE_API_KEY}`,
  };
  const res = await fetch(url.toString(), {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  let data: unknown;
  try {
    data = await res.json();
  } catch {
    data = { error: "Invalid JSON from Late.com" };
  }
  return jsonResponse(
    res.ok ? (data as object) : { error: (data as any)?.message ?? (data as any)?.error ?? "Late API error" },
    res.status
  );
}

// ----- LinkedIn OAuth callback (public) -----
async function handleLinkedInCallback(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  const error = url.searchParams.get("error");

  const baseUrl = new URL(request.url).origin;

  if (error) {
    const back = url.searchParams.get("redirect_uri") ?? baseUrl;
    return redirectResponse(`${back}?error=${encodeURIComponent(error)}`);
  }
  if (!code || !state) {
    return htmlResponse("<p>Missing code or state. Try connecting again from the app.</p>", 400);
  }

  const stateJson = await env.SOCIAL_KV.get(`oauth_state:${state}`);
  await env.SOCIAL_KV.delete(`oauth_state:${state}`);
  if (!stateJson) {
    return htmlResponse("<p>Invalid or expired state. Try connecting again from the app.</p>", 400);
  }

  let stateData: { userId: string; profileId: string; redirectUrl?: string };
  try {
    stateData = JSON.parse(stateJson) as { userId: string; profileId: string; redirectUrl?: string };
  } catch {
    return htmlResponse("<p>Invalid state.</p>", 400);
  }

  const clientId = env.LINKEDIN_CLIENT_ID;
  const clientSecret = env.LINKEDIN_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    return htmlResponse("<p>LinkedIn is not configured on the server.</p>", 503);
  }

  const redirectUri = `${baseUrl}/oauth/linkedin/callback`;
  let tokens: { access_token: string; refresh_token?: string; expires_in: number };
  try {
    tokens = await exchangeLinkedInCode({
      code,
      clientId,
      clientSecret,
      redirectUri,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Token exchange failed";
    return htmlResponse(`<p>LinkedIn error: ${msg}</p>`, 400);
  }

  const payload = JSON.stringify({
    access_token: tokens.access_token,
    refresh_token: tokens.refresh_token,
    expires_in: tokens.expires_in,
    scope: tokens.scope,
  });
  await env.SOCIAL_KV.put(`linkedin:${stateData.userId}`, payload, {
    expirationTtl: tokens.expires_in > 0 ? Math.min(tokens.expires_in, 60 * 24 * 60) : 60 * 24 * 60,
  });

  const redirectUrl =
    stateData.redirectUrl && stateData.redirectUrl.startsWith("http")
      ? stateData.redirectUrl
      : `${baseUrl}/connected?platform=linkedin`;
  return redirectResponse(redirectUrl);
}

// ----- Bluesky connect page (form) and submit (public) -----
function blueskyConnectForm(state: string, error?: string): string {
  const errHtml = error ? `<p style="color:red">${error}</p>` : "";
  return `<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Connect Bluesky</title></head>
<body>
  <h1>Connect Bluesky</h1>
  <p>Use your Bluesky handle and an <strong>App Password</strong> (not your main password). Create one in Bluesky: Settings → App passwords.</p>
  ${errHtml}
  <form method="post" action="/connect/bluesky">
    <input type="hidden" name="state" value="${state}">
    <label>Handle (e.g. you.bsky.social)<br><input type="text" name="identifier" required placeholder="you.bsky.social"></label><br><br>
    <label>App password<br><input type="password" name="password" required placeholder="xxxx-xxxx-xxxx-xxxx"></label><br><br>
    <button type="submit">Connect</button>
  </form>
</body>
</html>`;
}

async function handleBlueskyConnectGet(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const state = url.searchParams.get("state");
  if (!state) {
    return htmlResponse("<p>Missing state. Open the link from the LUMARA app.</p>", 400);
  }
  const stateJson = await env.SOCIAL_KV.get(`oauth_state:${state}`);
  if (!stateJson) {
    return htmlResponse("<p>Invalid or expired link. Try connecting again from the app.</p>", 400);
  }
  return htmlResponse(blueskyConnectForm(state));
}

async function handleBlueskyConnectPost(request: Request, env: Env): Promise<Response> {
  const baseUrl = new URL(request.url).origin;
  let body: URLSearchParams;
  try {
    const text = await request.text();
    body = new URLSearchParams(text);
  } catch {
    return redirectResponse(`${baseUrl}/connect/bluesky?error=Bad+request`);
  }
  const state = body.get("state");
  const identifier = (body.get("identifier") ?? "").trim();
  const password = body.get("password") ?? "";
  if (!state || !identifier || !password) {
    return htmlResponse(blueskyConnectForm(state ?? "", "Handle and app password are required."), 400);
  }

  const stateJson = await env.SOCIAL_KV.get(`oauth_state:${state}`);
  await env.SOCIAL_KV.delete(`oauth_state:${state}`);
  if (!stateJson) {
    return htmlResponse("<p>Invalid or expired link. Try connecting again from the app.</p>", 400);
  }
  let stateData: { userId: string; profileId: string; redirectUrl?: string };
  try {
    stateData = JSON.parse(stateJson) as { userId: string; profileId: string; redirectUrl?: string };
  } catch {
    return htmlResponse("<p>Invalid state.</p>", 400);
  }

  let session: { accessJwt: string; refreshJwt: string; handle: string; did: string };
  try {
    session = await createBlueskySession({ identifier, password });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Login failed";
    return htmlResponse(blueskyConnectForm(state, msg), 400);
  }

  const payload = JSON.stringify({
    accessJwt: session.accessJwt,
    refreshJwt: session.refreshJwt,
    handle: session.handle,
    did: session.did,
  });
  await env.SOCIAL_KV.put(`bluesky:${stateData.userId}`, payload, {
    expirationTtl: 60 * 24 * 60,
  });

  const redirectUrl =
    stateData.redirectUrl && stateData.redirectUrl.startsWith("http")
      ? stateData.redirectUrl
      : `${baseUrl}/connected?platform=bluesky`;
  return redirectResponse(redirectUrl);
}

// ----- /connected landing (optional) -----
function handleConnectedPage(request: Request): Response {
  const url = new URL(request.url);
  const platform = url.searchParams.get("platform") ?? "account";
  return htmlResponse(
    `<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Connected</title></head>
<body>
  <h1>${platform === "linkedin" ? "LinkedIn" : platform === "bluesky" ? "Bluesky" : "Account"} connected</h1>
  <p>You can close this window and return to LUMARA.</p>
</body>
</html>`
  );
}

// ----- Invoke handler (Bearer required) -----
async function handleInvoke(request: Request, env: Env): Promise<Response> {
  const auth = request.headers.get("Authorization");
  const token = env.SWARMSPACE_INTERNAL_TOKEN;
  if (!token || auth !== `Bearer ${token}`) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let payload: Record<string, any>;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const action = payload._action as string;
  if (!action) {
    return jsonResponse({ error: "_action is required" }, 400);
  }

  const userId = request.headers.get("X-SwarmSpace-User-Id") ?? "";
  const baseUrl = new URL(request.url).origin;

  switch (action) {
    case "publish": {
      const { content, platforms, mediaUrls, scheduledFor, timezone } = payload;
      if (!content || !Array.isArray(platforms) || platforms.length === 0) {
        return jsonResponse({ error: "content and platforms[] required" }, 400);
      }
      const body: any = { content, platforms };
      if (mediaUrls?.length) body.mediaUrls = mediaUrls;
      if (scheduledFor) body.scheduledFor = scheduledFor;
      if (timezone) body.timezone = timezone;
      return lateFetch("/posts", "POST", env, body);
    }
    case "accounts": {
      const profileId = payload.profileId as string | undefined;
      const q: Record<string, string> = {};
      if (profileId) q.profileId = profileId;
      return lateFetch("/accounts", "GET", env, undefined, Object.keys(q).length ? q : undefined);
    }
    case "profiles": {
      return lateFetch("/profiles", "GET", env);
    }
    case "createProfile": {
      const name = payload.name as string;
      const description = (payload.description as string) ?? "";
      if (!name) return jsonResponse({ error: "name required" }, 400);
      return lateFetch("/profiles", "POST", env, { name, description });
    }
    case "connectUrl": {
      const platform = (payload.platform as string)?.toLowerCase();
      const profileId = payload.profileId as string;
      const redirectUrl = payload.redirectUrl as string | undefined;
      if (!platform || !profileId) {
        return jsonResponse({ error: "platform and profileId required" }, 400);
      }

      if (platform === "linkedin") {
        const clientId = env.LINKEDIN_CLIENT_ID;
        if (!clientId) {
          return jsonResponse({ error: "LinkedIn is not configured (missing LINKEDIN_CLIENT_ID)" }, 503);
        }
        const stateId = crypto.randomUUID();
        await env.SOCIAL_KV.put(
          `oauth_state:${stateId}`,
          JSON.stringify({ userId, profileId, redirectUrl }),
          { expirationTtl: OAUTH_STATE_TTL }
        );
        const callbackUrl = `${baseUrl}/oauth/linkedin/callback`;
        const connectUrl = buildLinkedInAuthUrl({
          clientId,
          redirectUri: callbackUrl,
          state: stateId,
        });
        return jsonResponse({ connectUrl }, 200);
      }

      if (platform === "bluesky") {
        const stateId = crypto.randomUUID();
        await env.SOCIAL_KV.put(
          `oauth_state:${stateId}`,
          JSON.stringify({ userId, profileId, redirectUrl }),
          { expirationTtl: OAUTH_STATE_TTL }
        );
        const connectUrl = `${baseUrl}/connect/bluesky?state=${encodeURIComponent(stateId)}`;
        return jsonResponse({ connectUrl }, 200);
      }

      // Fallback: Late.com
      const q: Record<string, string> = { profileId };
      if (redirectUrl) q.redirectUrl = redirectUrl;
      const res = await fetch(`${LATE_BASE}/connect/${platform}?${new URLSearchParams(q)}`, {
        method: "GET",
        headers: { Authorization: `Bearer ${env.LATE_API_KEY}` },
        redirect: "manual",
      });
      const location = res.headers.get("Location");
      const connectUrl = location ?? `${LATE_BASE}/connect/${platform}?${new URLSearchParams(q)}`;
      return jsonResponse({ connectUrl }, 200);
    }
    case "status": {
      const postId = payload.postId as string;
      if (!postId) return jsonResponse({ error: "postId required" }, 400);
      return lateFetch(`/posts/${postId}/status`, "GET", env);
    }
    default:
      return jsonResponse({ error: `Unknown _action: ${action}` }, 400);
  }
}

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    if (path === "/oauth/linkedin/callback" && request.method === "GET") {
      return handleLinkedInCallback(request, env);
    }
    if (path === "/connect/bluesky") {
      if (request.method === "GET") return handleBlueskyConnectGet(request, env);
      if (request.method === "POST") return handleBlueskyConnectPost(request, env);
    }
    if (path === "/connected" && request.method === "GET") {
      return handleConnectedPage(request);
    }
    if (path === "/invoke" && request.method === "POST") {
      return handleInvoke(request, env);
    }

    return jsonResponse({ error: "Not found" }, 404);
  },
};
