// crypto.ts - Encrypt/decrypt API keys for per-user LLM settings
// Uses AES-256-GCM. Key must be 32 bytes (64 hex chars).

import * as crypto from "crypto";

const ALGORITHM = "aes-256-gcm";
const IV_LENGTH = 16;

function getKeyBuffer(hexKey: string): Buffer {
  if (!hexKey || hexKey.length !== 64 || !/^[0-9a-fA-F]+$/.test(hexKey)) {
    throw new Error("LLM_SETTINGS_ENCRYPTION_KEY must be a 64-character hex string (32 bytes)");
  }
  return Buffer.from(hexKey, "hex");
}

/** Encrypt plaintext. Returns base64: iv:authTag:ciphertext */
export function encrypt(plaintext: string, hexKey: string): string {
  const key = getKeyBuffer(hexKey);
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  let encrypted = cipher.update(plaintext, "utf8", "base64");
  encrypted += cipher.final("base64");
  const authTag = cipher.getAuthTag();
  return [iv.toString("base64"), authTag.toString("base64"), encrypted].join(":");
}

/** Decrypt ciphertext produced by encrypt() */
export function decrypt(encoded: string, hexKey: string): string {
  const key = getKeyBuffer(hexKey);
  const parts = encoded.split(":");
  if (parts.length !== 3) {
    throw new Error("Invalid encrypted payload");
  }
  const [ivB64, authTagB64, ciphertext] = parts;
  const iv = Buffer.from(ivB64, "base64");
  const authTag = Buffer.from(authTagB64, "base64");
  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(authTag);
  return decipher.update(ciphertext, "base64", "utf8") + decipher.final("utf8");
}
