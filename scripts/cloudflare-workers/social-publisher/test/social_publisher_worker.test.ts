/**
 * Phase 7: Social Publisher Worker tests.
 * POST /invoke without token → 401; valid publish forwards to Late.com; GET /accounts returns list.
 */

import { describe, it, expect, vi, beforeEach } from "vitest";
// @ts-ignore - worker default export
import worker from "../src/index";

const env = {
  SWARMSPACE_INTERNAL_TOKEN: "test-secret-token",
  LATE_API_KEY: "test-late-key",
};

function postInvoke(body: object, auth?: string): Promise<Response> {
  return worker.fetch(
    new Request("https://worker.test/invoke", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(auth !== undefined ? { Authorization: auth } : {}),
      },
      body: JSON.stringify(body),
    }),
    env,
    {} as ExecutionContext
  );
}

describe("social-publisher worker", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("POST /invoke returns 401 without Authorization header", async () => {
    const res = await postInvoke({ _action: "publish", content: "hi", platforms: [{ platform: "linkedin", accountId: "acc_1" }] });
    expect(res.status).toBe(401);
    const json = await res.json();
    expect(json.error).toBe("Unauthorized");
  });

  it("POST /invoke returns 401 with wrong token", async () => {
    const res = await postInvoke(
      { _action: "publish", content: "hi", platforms: [{ platform: "linkedin", accountId: "acc_1" }] },
      "Bearer wrong-token"
    );
    expect(res.status).toBe(401);
  });

  it("valid publish request forwards to Late.com and returns response", async () => {
    const mockFetch = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({ postId: "post_123", status: "published", platformResults: {} }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    );
    (globalThis as any).fetch = mockFetch;

    const res = await postInvoke(
      {
        _action: "publish",
        content: "Hello world",
        platforms: [{ platform: "linkedin", accountId: "acc_xxx" }],
      },
      "Bearer test-secret-token"
    );

    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.postId).toBe("post_123");
    expect(json.status).toBe("published");
    expect(mockFetch).toHaveBeenCalledWith(
      "https://getlate.dev/api/v1/posts",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          Authorization: "Bearer test-late-key",
          "Content-Type": "application/json",
        }),
        body: JSON.stringify({
          content: "Hello world",
          platforms: [{ platform: "linkedin", accountId: "acc_xxx" }],
        }),
      })
    );
  });

  it("GET /accounts (via invoke) returns account list from Late.com", async () => {
    const mockFetch = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify([
          { id: "acc_1", platform: "linkedin", username: "jane", profileId: "p1" },
        ]),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    );
    (globalThis as any).fetch = mockFetch;

    const res = await postInvoke(
      { _action: "accounts", profileId: "p1" },
      "Bearer test-secret-token"
    );

    expect(res.status).toBe(200);
    const json = await res.json();
    expect(Array.isArray(json)).toBe(true);
    expect(json.length).toBe(1);
    expect(json[0].id).toBe("acc_1");
    expect(json[0].platform).toBe("linkedin");
    expect(json[0].username).toBe("jane");
    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("https://getlate.dev/api/v1/accounts"),
      expect.objectContaining({ method: "GET" })
    );
  });
});
