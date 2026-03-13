// functions/src/functions/visionOcrInvoke.ts
//
// SwarmSpace Vision/OCR plugin — Firebase HTTP function
//
// Two modes:
//   - ocr: Cloud Vision API TEXT_DETECTION — extract raw text from image
//   - understand: Gemini multimodal — describe/summarize/answer questions about the image
//
// Params: image_b64 (base64 string) or image_url (we fetch), mode: "ocr" | "understand"
//   For understand: optional prompt (default: "Describe this image and any text in it.")
//
// Set secrets: SWARMSPACE_INTERNAL_TOKEN, GEMINI_API_KEY
// Enable Cloud Vision API and grant the function's SA Vision API User.

import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { ImageAnnotatorClient } from "@google-cloud/vision";
import { GoogleGenerativeAI } from "@google/generative-ai";

const SWARMSPACE_INTERNAL_TOKEN = defineSecret("SWARMSPACE_INTERNAL_TOKEN");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

export const visionOcrInvoke = onRequest(
  {
    secrets: [SWARMSPACE_INTERNAL_TOKEN, GEMINI_API_KEY],
    cors: true,
    invoker: "public",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    const authHeader = req.headers.authorization;
    const expectedToken = SWARMSPACE_INTERNAL_TOKEN.value();
    if (!authHeader || authHeader !== `Bearer ${expectedToken}`) {
      logger.warn("visionOcrInvoke: unauthorized request");
      res.status(403).json({ error: "Unauthorized" });
      return;
    }

    const params = (typeof req.body === "object" ? req.body : {}) as Record<string, unknown>;
    const mode = ((params.mode as string) ?? "ocr").toLowerCase() === "understand" ? "understand" : "ocr";
    const prompt = (params.prompt as string) ?? "Describe this image and any text in it. Be concise.";

    let imageBuffer: Buffer;
    const imageB64 = params.image_b64 as string | undefined;
    const imageUrl = params.image_url as string | undefined;

    if (imageB64) {
      try {
        imageBuffer = Buffer.from(imageB64, "base64");
      } catch {
        res.status(400).json({ error: "Invalid image_b64" });
        return;
      }
    } else if (imageUrl) {
      try {
        const resp = await fetch(imageUrl, { signal: AbortSignal.timeout(15_000) });
        if (!resp.ok) {
          res.status(400).json({ error: "Failed to fetch image from URL" });
          return;
        }
        const arr = new Uint8Array(await resp.arrayBuffer());
        imageBuffer = Buffer.from(arr);
      } catch (e) {
        logger.warn("visionOcrInvoke: image_url fetch failed", e);
        res.status(400).json({ error: "Failed to fetch image from URL" });
        return;
      }
    } else {
      res.status(400).json({ error: "Provide image_b64 or image_url" });
      return;
    }

    try {
      if (mode === "ocr") {
        const client = new ImageAnnotatorClient();
        const [result] = await client.textDetection({ image: { content: imageBuffer } });
        const text = result.fullTextAnnotation?.text?.trim() ?? "";
        res.status(200).json({ mode: "ocr", text });
        return;
      }

      // understand: Gemini with image
      const apiKey = GEMINI_API_KEY.value();
      if (!apiKey?.trim()) {
        res.status(500).json({ error: "Gemini not configured" });
        return;
      }
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: "gemini-3-flash-preview" });
      const imagePart = {
        inlineData: {
          mimeType: "image/jpeg",
          data: imageBuffer.toString("base64"),
        },
      };
      const result = await model.generateContent([prompt, imagePart]);
      const response = result.response;
      const text = response.text()?.trim() ?? "";
      res.status(200).json({ mode: "understand", text, prompt });
    } catch (err) {
      logger.error("visionOcrInvoke error", err);
      res.status(500).json({
        error: err instanceof Error ? err.message : "Vision/OCR failed",
      });
    }
  }
);
