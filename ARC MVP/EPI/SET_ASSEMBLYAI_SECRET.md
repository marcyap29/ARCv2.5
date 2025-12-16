# Set AssemblyAI API Key Secret

## Problem
The `getAssemblyAIToken` function now requires a real AssemblyAI API key to work. The function has been updated to use Firebase Secrets to securely store the API key.

## Solution

You need to set the `ASSEMBLYAI_API_KEY` secret in Firebase Functions.

### Step 1: Get Your AssemblyAI API Key

1. Go to [AssemblyAI Dashboard](https://www.assemblyai.com/app/account)
2. Sign in or create an account
3. Navigate to your API key (usually in Account Settings or API Keys section)
4. Copy your API key

### Step 2: Set the Secret in Firebase

**Option A: Using Firebase CLI (Recommended)**

```bash
cd "/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI"
firebase functions:secrets:set ASSEMBLYAI_API_KEY
```

When prompted, paste your AssemblyAI API key.

**Option B: Using Google Cloud Console**

1. Go to [Google Cloud Secret Manager](https://console.cloud.google.com/security/secret-manager?project=arc-epi)
2. Click **"Create Secret"**
3. Name: `ASSEMBLYAI_API_KEY`
4. Secret value: Paste your AssemblyAI API key
5. Click **"Create Secret"**
6. Grant the Cloud Functions service account access to the secret:
   - Click on the secret
   - Go to **"Permissions"** tab
   - Click **"Add Principal"**
   - Principal: `563971839074-compute@developer.gserviceaccount.com` (or your project's compute service account)
   - Role: **"Secret Manager Secret Accessor"**
   - Click **"Save"**

### Step 3: Deploy the Function

After setting the secret, deploy the updated function:

```bash
cd "/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI"
firebase deploy --only functions:getAssemblyAIToken
```

## Verification

After deployment, test the function by:
1. Restarting your Flutter app
2. Trying voice journal mode
3. You should see: `AssemblyAI: Token fetched successfully`
4. The WebSocket should stay connected and transcription should work

## Security Note

- The API key is stored securely in Firebase Secrets
- It's only accessible to the Cloud Functions service account
- Never commit the API key to version control
- The key is passed to the client app, but only for authenticated premium users
