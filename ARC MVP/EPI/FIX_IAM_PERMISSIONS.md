# Fix Firebase Functions v2 IAM Permissions

## Problem
Firebase Functions v2 callable functions are returning `UNAUTHENTICATED` errors because the underlying Cloud Run services don't have the proper IAM permissions to allow invocations.

## Solution

Firebase Functions v2 uses Cloud Run under the hood. For callable functions to work, the Cloud Run service needs to allow `allUsers` to invoke it (the function code itself will still verify Firebase Authentication).

### Option 1: Using Google Cloud Console (Recommended if gcloud is not installed)

**Method 1: Change Authentication Setting (Easiest for Firebase Callable Functions)**

1. Go to [Google Cloud Run Console](https://console.cloud.google.com/run?project=arc-epi)
2. For each function (`getUserSubscription` and `getAssemblyAIToken`):
   - Click on the function name
   - Go to the **"Security"** tab
   - Under **"Authentication"**, select **"Allow public access"** (instead of "Require authentication")
   - Click **"Save"** at the bottom of the page

**Why this works:** Firebase callable functions handle authentication at the function code level (via `request.auth`). The Cloud Run service just needs to allow the HTTP request to reach the function. Your function code will still verify Firebase Authentication, so only authenticated users can actually use the function.

**Method 2: Set IAM Permissions via Project IAM (If Method 1 doesn't work)**

1. Go to [IAM & Admin Console](https://console.cloud.google.com/iam-admin/iam?project=arc-epi)
2. Click **"Grant Access"** at the top
3. In the **"New principals"** field, enter: `allUsers`
4. Select the role: **"Cloud Run Invoker"** (`roles/run.invoker`)
5. Under **"Condition"**, click **"Add condition"** (optional, but recommended):
   - Condition type: **"Resource name"**
   - Resource name contains: `getUserSubscription` (for the first function)
   - Or use: `getAssemblyAIToken` (for the second function)
6. Click **"Save"**
7. Repeat for the other function

**Method 3: Use Service List View**

1. Go to [Cloud Run Services List](https://console.cloud.google.com/run?project=arc-epi)
2. Check the checkbox next to `getUserSubscription`
3. Click the **"Permissions"** button in the top toolbar (if visible)
4. Click **"Add Principal"**
5. Enter `allUsers` and select **"Cloud Run Invoker"** role
6. Click **"Save"**

### Option 2: Using gcloud CLI

If you have gcloud CLI installed, run:

```bash
cd "/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI"
./set-function-iam.sh
```

Or manually:

```bash
# For getUserSubscription
gcloud run services add-iam-policy-binding getUserSubscription \
  --region=us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --project=arc-epi

# For getAssemblyAIToken
gcloud run services add-iam-policy-binding getAssemblyAIToken \
  --region=us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --project=arc-epi
```

## Why This Works

- Firebase Functions v2 callable functions need `allUsers` to have the `roles/run.invoker` permission at the Cloud Run level
- This allows the HTTP request to reach the function
- The function code then checks `request.auth` to verify Firebase Authentication
- So even though `allUsers` can invoke, only authenticated Firebase users will actually get past the authentication check in the function code

## Security Note

This is the standard configuration for Firebase callable functions. The security is maintained by:
1. The function code checking `request.auth` 
2. Firebase Authentication verifying the ID token
3. Optional: Firebase App Check for additional protection

## After Setting Permissions

Once IAM permissions are set, restart your Flutter app and the functions should work correctly. You should see:
- ✅ Premium tier detected for marcyap@orbitalai.net
- ✅ AssemblyAI token fetched successfully
- ✅ No more UNAUTHENTICATED errors
