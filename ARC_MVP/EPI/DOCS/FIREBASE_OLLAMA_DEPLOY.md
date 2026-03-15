# Deploying proxyOllama and fixing "Unable to set the invoker" IAM error

The **proxyOllama** Cloud Function (3rd fallback: Gemini → Groq → Ollama Cloud) can fail at deploy with:

```text
Unable to set the invoker for the IAM policy on the following functions:
  proxyOllama(us-central1)
```

The function is often **created**; only the IAM step fails. Fix it with one of the options below.

---

## Option 1: Set invoker via gcloud (quick fix)

**proxyOllama** is a 2nd gen function, so it runs as a **Cloud Run** service. Use the Cloud Run IAM command (not `gcloud functions add-invoker-policy-binding`).

Use an account that can change IAM on the project (e.g. Owner or **Cloud Run Admin**).

From the **project root**:

```bash
gcloud config set project arc-epi

# 2nd gen = Cloud Run service; name is lowercase "proxyollama"
gcloud run services add-iam-policy-binding proxyollama \
  --region=us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"
```

Then try calling the app again; no need to redeploy.

### If you get "do not belong to a permitted customer" (org policy)

Your organization policy (e.g. **Domain Restricted Sharing**) blocks adding `allUsers`. Use **invoker IAM check disabled** instead so Cloud Run doesn’t require an invoker binding; your function still enforces auth with `enforceAuth()`:

```bash
gcloud config set project arc-epi

gcloud run services update proxyollama \
  --region=us-central1 \
  --no-invoker-iam-check
```

After this, the service accepts requests without an `allUsers` (or other) IAM binding. Auth remains enforced inside the function.

### Same fix in Google Cloud Console (no gcloud)

1. Open **[Cloud Run](https://console.cloud.google.com/run)** and ensure the project is **arc-epi**.
2. In the list, **click the service name** **proxyollama** (not the checkbox).
3. Open the **Security** tab.
4. Select **Allow public access** (this disables the invoker IAM check).
5. Click **Save**.

Your function still enforces auth with `enforceAuth()`; this only lets the HTTPS request reach the function.

---

## Option 2: Grant yourself Cloud Functions Admin

If you prefer the Firebase CLI to set IAM on future deploys:

1. Open [Google Cloud Console → IAM](https://console.cloud.google.com/iam-admin/iam?project=arc-epi).
2. Find your user and **Edit** (pencil).
3. **Add another role** → **Cloud Functions Admin** (or **Cloud Run Admin** for 2nd gen).
4. Save.
5. Run again:  
   `cd functions && npm run build && cd .. && firebase deploy --only functions:proxyOllama`

---

## Option 3: Set invoker in Cloud Console

1. Open [Cloud Run](https://console.cloud.google.com/run?project=arc-epi).
2. Find the service **proxyollama** (lowercase).
3. Open it → **Permissions** → **Add principal**.
4. Principal: `allUsers`. Role: **Cloud Run Invoker**.
5. Save.

---

## Notes

- **proxyOllama** still requires a valid Firebase Auth token; `enforceAuth()` runs inside the function. `allUsers` only allows the HTTPS request to reach the function; unauthenticated callers get an error from your code.
- If your org has a **Domain restricted sharing** policy, it may block adding `allUsers`. An org admin may need to allow the exception or use a different invoker (e.g. a service account used by the app).
