# Set Groq API Key in Firebase

The **proxyGroq** Cloud Function calls the Groq API (Llama 3.3 70B / Mixtral) with the API key stored in Firebase Secret Manager so the key never touches the client.

## 1. Get a Groq API key

1. Go to [Groq Console](https://console.groq.com/)
2. Sign in or create an account
3. Open **API Keys** and create a key
4. Copy the key

## 2. Set the secret in Firebase

**Using Firebase CLI (recommended):**

```bash
cd "ARC MVP/EPI"
firebase functions:secrets:set GROQ_API_KEY
```

When prompted, paste your Groq API key.

**Using Google Cloud Console:**

1. Open [Secret Manager](https://console.cloud.google.com/security/secret-manager) for your project
2. Create a secret named `GROQ_API_KEY` with the key as the value
3. Ensure the Cloud Functions service account has **Secret Manager Secret Accessor** on this secret

## 3. Deploy the function

```bash
firebase deploy --only functions:proxyGroq
```

Or deploy all functions:

```bash
firebase deploy --only functions
```

## Behavior in the app

- **Signed-in users:** When Firebase is ready and the user is authenticated, LUMARA uses **proxyGroq** (no client-side Groq key needed).
- **Optional client key:** Users can still add a Groq API key in LUMARA settings; it is used when not signed in or when Firebase is unavailable.
