/**
 * Bluesky AT Protocol — createSession (handle + app password).
 * Docs: https://docs.bsky.app/docs/api/com-atproto-server-create-session
 */

const BSKY_PDS = "https://bsky.social";

export interface BlueskySession {
  accessJwt: string;
  refreshJwt: string;
  handle: string;
  did: string;
}

export async function createBlueskySession(params: {
  identifier: string;
  password: string;
}): Promise<BlueskySession> {
  const res = await fetch(`${BSKY_PDS}/xrpc/com.atproto.server.createSession`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      identifier: params.identifier,
      password: params.password,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Bluesky createSession failed: ${res.status} ${err}`);
  }

  const data = (await res.json()) as {
    accessJwt: string;
    refreshJwt: string;
    handle: string;
    did: string;
  };
  return {
    accessJwt: data.accessJwt,
    refreshJwt: data.refreshJwt,
    handle: data.handle,
    did: data.did,
  };
}
