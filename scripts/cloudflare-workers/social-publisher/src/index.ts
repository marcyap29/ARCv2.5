/**
 * SwarmSpace Social Publisher Worker
 * Proxies LUMARA app → Late.com API. All Late.com calls use server-side LATE_API_KEY.
 * Auth: Authorization: Bearer SWARMSPACE_INTERNAL_TOKEN
 * Router forwards to POST /invoke with body { _action, ...params }
 */

export interface Env {
  SWARMSPACE_INTERNAL_TOKEN: string;
  LATE_API_KEY: string;
}

const LATE_BASE = "https://getlate.dev/api/v1";

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
  };
}

function jsonResponse(body: object, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
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

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    const auth = request.headers.get("Authorization");
    const token = env.SWARMSPACE_INTERNAL_TOKEN;
    if (!token || auth !== `Bearer ${token}`) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const url = new URL(request.url);
    if (url.pathname !== "/invoke" || request.method !== "POST") {
      return jsonResponse({ error: "Not found" }, 404);
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
        const res = await lateFetch("/posts", "POST", env, body);
        return res;
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
        const res = await lateFetch("/profiles", "POST", env, { name, description });
        return res;
      }
      case "connectUrl": {
        const platform = payload.platform as string;
        const profileId = payload.profileId as string;
        const redirectUrl = payload.redirectUrl as string | undefined;
        if (!platform || !profileId) {
          return jsonResponse({ error: "platform and profileId required" }, 400);
        }
        const q: Record<string, string> = { profileId };
        if (redirectUrl) q.redirectUrl = redirectUrl;
        const res = await fetch(
          `${LATE_BASE}/connect/${platform}?${new URLSearchParams(q)}`,
          {
            method: "GET",
            headers: { Authorization: `Bearer ${env.LATE_API_KEY}` },
            redirect: "manual",
          }
        );
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
  },
};
