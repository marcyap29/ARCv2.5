# Firebase Gemini API Key Secret — Setup & Run

The **Analysis** mode (Mode 3) in LUMARA uses the `proxyGemini` Cloud Function, which reads the Gemini API key from a Firebase secret. No API key is stored in the app.

---

## 1. Get a Gemini API key

1. Open [Google AI Studio](https://aistudio.google.com/apikey).
2. Create an API key (or use an existing one).
3. Copy the key (you’ll use it in the next step).

---

## 2. Set the Firebase secret

From the **project root** (where `firebase.json` lives), run one of the following.

### Option A: Interactive (prompted for the key)

```bash
cd /Users/mymac/Software/Development/ARCv2.5
firebase functions:secrets:set GEMINI_API_KEY
```

When prompted, paste your Gemini API key and press Enter.

### Option B: From an environment variable (no paste in terminal)

```bash
cd /Users/mymac/Software/Development/ARCv2.5
echo -n "$GEMINI_API_KEY" | firebase functions:secrets:set GEMINI_API_KEY --data-file=-
```

Set `GEMINI_API_KEY` in your shell first, or run:

```bash
export GEMINI_API_KEY="your-actual-key-here"
echo -n "$GEMINI_API_KEY" | firebase functions:secrets:set GEMINI_API_KEY --data-file=-
```

### Option C: Using the setup script (recommended)

From the project root:

```bash
./scripts/set-gemini-secret.sh
```

The script reads `GEMINI_API_KEY` from your environment; create a `.env` or export it before running (see script contents below).

---

## 3. Build and deploy functions

From the project root:

```bash
cd functions
npm run build
cd ..
firebase deploy --only functions
```

Or in one line from the project root:

```bash
cd functions && npm run build && cd .. && firebase deploy --only functions
```

Or use the deploy script:

```bash
./scripts/deploy-functions.sh
```

---

## 4. Verify

1. In the app, sign in (proxy requires auth).
2. Open LUMARA chat and select **Analysis**.
3. Send a message — it should go through `proxyGemini` using the secret.

To confirm the secret is set (name only, not value):

```bash
firebase functions:secrets:access GEMINI_API_KEY  # optional: prints secret; use with care
```

---

## Summary

| Step | Command |
|------|--------|
| Set secret | `firebase functions:secrets:set GEMINI_API_KEY` (then paste key) |
| Build | `cd functions && npm run build` |
| Deploy | `firebase deploy --only functions` |

The Cloud Function `proxyGemini` in `functions/src/functions/proxyGemini.ts` already declares `secrets: [GEMINI_API_KEY]`; no code changes are required once the secret is set and functions are deployed.
