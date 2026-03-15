/**
 * SwarmSpace R2 media upload worker
 * POST /upload: multipart/form-data image → R2 at media/{uuid}.{ext} → { url }
 * Auth: Authorization: Bearer SWARMSPACE_INTERNAL_TOKEN
 * Paths use UUID v4 only — never sequential IDs.
 */

export interface Env {
  MEDIA_BUCKET: R2Bucket;
  SWARMSPACE_INTERNAL_TOKEN: string;
  PUBLIC_MEDIA_BASE_URL?: string;
}

const ALLOWED_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
]);

function extFromMime(mime: string): string {
  if (mime.includes("jpeg") || mime.includes("jpg")) return "jpg";
  if (mime.includes("png")) return "png";
  if (mime.includes("webp")) return "webp";
  if (mime.includes("gif")) return "gif";
  return "bin";
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: corsHeaders(),
      });
    }
    if (url.pathname === "/upload" && request.method === "POST") {
      return handleUpload(request, env);
    }
    if (request.method === "GET" && url.pathname.startsWith("/media/")) {
      return serveMedia(url.pathname.slice(1), env);
    }
    return new Response(JSON.stringify({ error: "Not found" }), {
      status: 404,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  },
};

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
  };
}

async function handleUpload(request: Request, env: Env): Promise<Response> {
  const auth = request.headers.get("Authorization");
  const token = env.SWARMSPACE_INTERNAL_TOKEN;
  if (!token || auth !== `Bearer ${token}`) {
    return jsonResponse({ error: "Unauthorized" }, 403);
  }

  let formData: FormData;
  try {
    formData = await request.formData();
  } catch {
    return jsonResponse({ error: "Invalid form data" }, 400);
  }

  const file = formData.get("file") ?? formData.get("image") ?? formData.get("upload");
  if (!file || typeof file === "string") {
    return jsonResponse({ error: "Missing file (use field: file, image, or upload)" }, 400);
  }

  const f = file as File;
  const mime = (f.type || "application/octet-stream").toLowerCase();
  if (!ALLOWED_TYPES.has(mime)) {
    return jsonResponse({ error: "Unsupported type. Use image/jpeg, image/png, image/webp, or image/gif." }, 400);
  }

  const uuid = crypto.randomUUID();
  const ext = extFromMime(mime);
  const key = `media/${uuid}.${ext}`;

  const arrayBuffer = await f.arrayBuffer();
  await env.MEDIA_BUCKET.put(key, arrayBuffer, {
    httpMetadata: {
      contentType: mime,
    },
    customMetadata: {
      "uploaded-at": new Date().toISOString(),
    },
  });

  const baseUrl = env.PUBLIC_MEDIA_BASE_URL?.replace(/\/$/, "") ?? "";
  const publicUrl = baseUrl ? `${baseUrl}/${key}` : `https://swarmspace-media-upload.orbitalai.workers.dev/${key}`;

  return jsonResponse({ url: publicUrl }, 200);
}

async function serveMedia(path: string, env: Env): Promise<Response> {
  if (!path.startsWith("media/") || path.includes("..")) {
    return new Response("Not found", { status: 404 });
  }
  const object = await env.MEDIA_BUCKET.get(path);
  if (!object) return new Response("Not found", { status: 404 });
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("Cache-Control", "public, max-age=86400");
  return new Response(object.body, { headers });
}

function jsonResponse(body: object, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}
