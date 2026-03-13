# Cloud Vision API setup for Vision/OCR plugin

The **vision-ocr** SwarmSpace plugin uses **Google Cloud Vision API** for OCR (text extraction). Enable the API and grant the function’s service account access.

**Project:** `arc-epi` (or your Firebase project ID)

Run the commands below in your own terminal (gcloud must be able to write to `~/.config/gcloud`).

---

## 1. Enable the Cloud Vision API

**Option A – gcloud (recommended)**

```bash
# Use your Firebase project
gcloud config set project arc-epi

# Enable the Vision API
gcloud services enable vision.googleapis.com
```

**Option B – Console**

1. Open [Google Cloud Console → APIs & Services → Library](https://console.cloud.google.com/apis/library).
2. Select project **arc-epi**.
3. Search for **Cloud Vision API**.
4. Open it and click **Enable**.

---

## 2. Grant the function’s service account access

Firebase Gen 2 (Cloud Run) uses the **default App Engine service account**:

`arc-epi@appspot.gserviceaccount.com`

Cloud Vision API has no dedicated IAM role. Grant **Service Usage Consumer** so the account can use enabled APIs (including Vision):

**Option A – gcloud**

```bash
gcloud projects add-iam-policy-binding arc-epi \
  --member="serviceAccount:arc-epi@appspot.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"
```

**Option B – Console**

1. Go to [IAM & Admin → IAM](https://console.cloud.google.com/iam-admin/iam).
2. Select project **arc-epi**.
3. Find **arc-epi@appspot.gserviceaccount.com** (App Engine default). If missing, click **Grant access** and add that principal.
4. Add role: **Service Usage Consumer** (`roles/serviceusage.serviceUsageConsumer`).
5. Save.

---

## 3. Deploy the vision-ocr function

Secrets `SWARMSPACE_INTERNAL_TOKEN` and `GEMINI_API_KEY` are already used by other functions. No extra secrets needed.

Use the **repo-root** `functions` (ARCv2.5/functions), not ARC_MVP/EPI/functions. From the **ARCv2.5** repo root:

```bash
cd /Users/mymac/Software/Development/ARCv2.5/functions
npm run build
cd ..
firebase deploy --only functions:visionOcrInvoke
```

If you see “No function matches the filter: visionOcrInvoke”, you’re in the wrong project dir (e.g. EPI). Use the repo root and run `firebase use arc-epi`; or deploy all functions: `firebase deploy --only functions`.

**If deploy fails with “Unable to set the invoker for the IAM policy”:** The function is still created. Set the invoker in Cloud Run: [Cloud Run → us-central1 → visionocrinvoke → Permissions → Grant access](https://console.cloud.google.com/run?project=arc-epi). Add principal `allUsers` with role **Cloud Run Invoker** (the function still requires `Authorization: Bearer SWARMSPACE_INTERNAL_TOKEN` from the router).

---

## 4. Verify

- In **Firebase Console → Functions**, confirm **visionOcrInvoke** is deployed.
- Call the plugin from LUMARA (e.g. Research or a test screen) with `plugin_id: 'vision-ocr'`, `image_b64` or `image_url`, and `mode: 'ocr'` or `'understand'`.
- Check **Cloud Logging** for `visionOcrInvoke` to see requests and any Vision API errors.

If you get **403** or “Vision API has not been used”, re-check that the Vision API is enabled and the App Engine default service account has **Service Usage Consumer** (`roles/serviceusage.serviceUsageConsumer`). If it already has **Editor** on the project, that also allows using enabled APIs.
