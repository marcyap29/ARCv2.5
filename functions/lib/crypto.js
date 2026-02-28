"use strict";
// crypto.ts - Encrypt/decrypt API keys for per-user LLM settings
// Uses AES-256-GCM. Key must be 32 bytes (64 hex chars).
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.encrypt = encrypt;
exports.decrypt = decrypt;
const crypto = __importStar(require("crypto"));
const ALGORITHM = "aes-256-gcm";
const IV_LENGTH = 16;
function getKeyBuffer(hexKey) {
    if (!hexKey || hexKey.length !== 64 || !/^[0-9a-fA-F]+$/.test(hexKey)) {
        throw new Error("LLM_SETTINGS_ENCRYPTION_KEY must be a 64-character hex string (32 bytes)");
    }
    return Buffer.from(hexKey, "hex");
}
/** Encrypt plaintext. Returns base64: iv:authTag:ciphertext */
function encrypt(plaintext, hexKey) {
    const key = getKeyBuffer(hexKey);
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
    let encrypted = cipher.update(plaintext, "utf8", "base64");
    encrypted += cipher.final("base64");
    const authTag = cipher.getAuthTag();
    return [iv.toString("base64"), authTag.toString("base64"), encrypted].join(":");
}
/** Decrypt ciphertext produced by encrypt() */
function decrypt(encoded, hexKey) {
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
//# sourceMappingURL=crypto.js.map