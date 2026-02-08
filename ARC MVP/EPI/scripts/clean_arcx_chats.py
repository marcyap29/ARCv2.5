#!/usr/bin/env python3
"""
Clean ARCX files: remove chat sessions that have fewer than 3 LUMARA (assistant) messages.
Only works with **password-encrypted** .arcx files (device-key encrypted cannot be decrypted by this script).

Usage:
  python3 scripts/clean_arcx_chats.py file1.arcx file2.arcx ...
  ARCX_PASSWORD=yourpass python3 scripts/clean_arcx_chats.py *.arcx   # password from env

Output: for each input file, writes <name>_cleaned.arcx in the same directory.
Original files are left unchanged.

Requires: pip install cryptography
"""

import argparse
import base64
import getpass
import hashlib
import io
import json
import os
import secrets
import sys
import zipfile
from pathlib import Path

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError:
    print("Error: 'cryptography' is required. Run: pip install cryptography", file=sys.stderr)
    sys.exit(1)

MIN_LUMARA_RESPONSES = 3  # Keep only chats with this many or more assistant messages


def derive_key(password: str, salt: bytes, iterations: int = 600_000) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations, dklen=32)


def decrypt_payload(ciphertext: bytes, password: str, salt_b64: str) -> bytes:
    salt = base64.b64decode(salt_b64)
    if len(salt) != 32:
        raise ValueError(f"Expected 32-byte salt, got {len(salt)}")
    key = derive_key(password, salt)
    if len(ciphertext) < 12 + 16:
        raise ValueError("Ciphertext too short")
    nonce = ciphertext[:12]
    tag = ciphertext[-16:]
    encrypted = ciphertext[12:-16]
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, encrypted + tag, None)


def encrypt_payload(plaintext: bytes, password: str) -> tuple[bytes, bytes]:
    salt = secrets.token_bytes(32)
    key = derive_key(password, salt)
    aesgcm = AESGCM(key)
    nonce = secrets.token_bytes(12)
    ciphertext_and_tag = aesgcm.encrypt(nonce, plaintext, None)
    # AESGCM.encrypt returns ciphertext || tag (16 bytes)
    return nonce + ciphertext_and_tag, salt


def count_assistant_messages(chat_json: dict) -> int:
    messages = chat_json.get("messages") or []
    return sum(1 for m in messages if m.get("role") == "assistant")


def clean_payload_and_rezip(
    payload_zip_bytes: bytes,
    min_assistant: int,
) -> tuple[bytes, int, int]:
    """Extract payload zip, remove short chats, return (new_zip_bytes, removed_count, kept_count)."""
    with zipfile.ZipFile(io.BytesIO(payload_zip_bytes), "r") as z:
        names = z.namelist()
    # Build new zip in memory: copy all entries except removed chat files
    buffer = io.BytesIO()
    removed = 0
    kept_chats = 0
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as out:
        with zipfile.ZipFile(io.BytesIO(payload_zip_bytes), "r") as z:
            for name in names:
                data = z.read(name)
                if name.startswith("Chats/") and name.endswith(".arcx.json"):
                    try:
                        chat = json.loads(data.decode("utf-8"))
                        if count_assistant_messages(chat) < min_assistant:
                            removed += 1
                            continue
                    except (json.JSONDecodeError, KeyError):
                        pass
                    kept_chats += 1
                out.writestr(name, data)
    return buffer.getvalue(), removed, kept_chats


def update_manifest_chats_count(manifest: dict, new_chats_count: int) -> None:
    if "scope" in manifest and isinstance(manifest["scope"], dict):
        manifest["scope"]["chats_count"] = new_chats_count


def process_arcx(
    input_path: Path,
    password: str,
    min_assistant: int = MIN_LUMARA_RESPONSES,
    dry_run: bool = False,
) -> bool:
    input_path = input_path.resolve()
    if not input_path.is_file():
        print(f"Skip (not a file): {input_path}")
        return False
    if input_path.suffix.lower() != ".arcx":
        print(f"Skip (not .arcx): {input_path}")
        return False

    out_path = input_path.parent / f"{input_path.stem}_cleaned.arcx"
    if dry_run:
        print(f"[DRY RUN] Would process: {input_path} -> {out_path}")
        return True

    with zipfile.ZipFile(input_path, "r") as arcx:
        if "manifest.json" not in arcx.namelist() or "archive.arcx" not in arcx.namelist():
            print(f"Skip (invalid ARCX): {input_path}")
            return False
        manifest_bytes = arcx.read("manifest.json")
        manifest = json.loads(manifest_bytes.decode("utf-8"))
        if not manifest.get("is_password_encrypted"):
            print(f"Skip (not password-encrypted; cannot decrypt): {input_path}")
            return False
        salt_b64 = manifest.get("salt_b64")
        if not salt_b64:
            print(f"Skip (no salt in manifest): {input_path}")
            return False
        ciphertext = arcx.read("archive.arcx")

    try:
        plaintext = decrypt_payload(ciphertext, password, salt_b64)
    except Exception as e:
        print(f"Decrypt failed for {input_path}: {e}")
        return False

    new_payload, removed, kept = clean_payload_and_rezip(plaintext, min_assistant)
    update_manifest_chats_count(manifest, kept)
    # Re-encrypt with same password (new salt for output)
    new_ciphertext, new_salt = encrypt_payload(new_payload, password)
    manifest["salt_b64"] = base64.b64encode(new_salt).decode("ascii")
    # Optionally clear signature since we changed content
    if "signature_b64" in manifest:
        manifest["signature_b64"] = ""
    if "sha256" in manifest:
        manifest["sha256"] = base64.b64encode(hashlib.sha256(new_ciphertext).digest()).decode("ascii")

    manifest_bytes = json.dumps(manifest, separators=(",", ":")).encode("utf-8")

    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as arcx_out:
        arcx_out.writestr("manifest.json", manifest_bytes)
        arcx_out.writestr("archive.arcx", new_ciphertext)

    print(f"OK: {input_path.name} -> {out_path.name}  (removed {removed} short chats, kept {kept})")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove chat sessions with fewer than 3 LUMARA messages from password-encrypted ARCX files."
    )
    parser.add_argument(
        "files",
        nargs="+",
        type=Path,
        help="Paths to .arcx files",
    )
    parser.add_argument(
        "--min-responses",
        type=int,
        default=MIN_LUMARA_RESPONSES,
        help=f"Minimum assistant messages to keep (default: {MIN_LUMARA_RESPONSES})",
    )
    parser.add_argument(
        "--password",
        default=os.environ.get("ARCX_PASSWORD"),
        help="Password (or set ARCX_PASSWORD); if not set, will prompt once",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only print what would be done",
    )
    args = parser.parse_args()

    password = args.password
    if not password and not args.dry_run:
        password = getpass.getpass("ARCX password: ")
    if not password and not args.dry_run:
        print("Password required.", file=sys.stderr)
        sys.exit(1)

    ok = 0
    for f in args.files:
        if process_arcx(f, password or "", min_assistant=args.min_responses, dry_run=args.dry_run):
            ok += 1
    if ok == 0 and not args.dry_run:
        sys.exit(1)
    print(f"Done: {ok} file(s) processed.")


if __name__ == "__main__":
    main()
